require "fileutils"
require "net/http"

module Engines
  # Downloads with aria2 (multi-connection, real pause/resume, survives restarts)
  # straight into a mounted folder such as /data/Movies.
  #
  # Only plain HTTP/HTTPS links: torrents and metalinks are turned off.
  class Aria2Engine
    STATUS_MAP = {
      "active"   => "downloading",
      "waiting"  => "pending",
      "paused"   => "paused",
      "complete" => "completed",
      "error"    => "failed",
      "removed"  => "cancelled"
    }.freeze

    SYNC_KEYS = %w[status totalLength completedLength downloadSpeed errorMessage].freeze

    # Servers answer 429/503 when we open too many connections or downloads.
    # aria2 gives up on those, so the download goes back in the queue and is
    # restarted after a growing wait, with fewer connections. The partial file
    # is kept, so it continues where it stopped.
    THROTTLED = /status=(429|503)\b/
    MAX_AUTO_RETRIES = 8
    MAX_BACKOFF = 300 # seconds

    def initialize(client: Aria2Client.new)
      @client = client
    end

    def start(download)
      head = probe(download.url)
      ext = FileExtension.detect(download.url, head[:disposition], head[:type])
      output_name = download.file_name_with(ext)

      # Never touch an existing file: aria2 would treat it as a partial download
      # of the new link and could append to it.
      target = File.join(download.folder_path, output_name)
      if File.exist?(target) && !File.exist?("#{target}.aria2")
        download.update!(status: "failed",
                         error_message: "#{output_name} already exists in #{download.folder_path}. Use a different name.")
        return
      end

      # Refuse up front when the file cannot fit (aria2 would fail half-way).
      space = DiskSpace.measure(download.destination_path)
      if head[:size].to_i.positive? && space && head[:size] > space[:free]
        download.update!(status: "failed", file_size: head[:size],
                         error_message: "Not enough space: needs #{Download.human_bytes(head[:size])}, " \
                                        "#{Download.human_bytes(space[:free])} free on the disk.")
        return
      end

      download.retries = 0 # a fresh start (or manual Resume) uses all connections again
      gid = add(download, output_name)
      download.update!(gid: gid, output_name: output_name, status: "pending",
                       file_size: head[:size], error_message: nil)
    rescue Aria2Client::Error => e
      download.update!(status: "failed", error_message: e.message)
    end

    def pause(download)
      # Waiting for an automatic retry: nothing is running in aria2 yet.
      return download.update!(status: "paused", download_speed: 0) if download.gid.blank?

      @client.call("aria2.forcePause", download.gid)
      download.update!(status: "paused", download_speed: 0)
    rescue Aria2Client::Error => e
      sync([download])
      download.errors.add(:base, e.message)
      false
    end

    def resume(download)
      @client.call("aria2.unpause", download.gid)
      download.update!(status: "pending")
    rescue Aria2Client::Error => e
      # aria2 lost it (e.g. it was restarted before saving its session): start again.
      Rails.logger.warn("aria2 unpause failed (#{e.message}); restarting download #{download.id}")
      start(download)
      !download.failed?
    end

    def cancel(download)
      begin
        @client.call("aria2.forceRemove", download.gid)
        wait_until_stopped(download.gid)
        @client.call("aria2.removeDownloadResult", download.gid)
      rescue Aria2Client::Error => e
        Rails.logger.warn("aria2 cancel for #{download.id}: #{e.message}")
      end
      remove_partial_files(download)
      download.update!(status: "cancelled", download_speed: 0)
    end

    # Movies: deletes the movie's folder (e.g. /data/Movies/Dangal (2016)).
    # TV: deletes only this episode/season file, since the season and show
    # folders hold other episodes, then removes folders left empty.
    def delete_files(download)
      cancel(download) if download.can_cancel?
      folder = download.folder_path
      raise "Refusing to delete outside the destination folder" unless download.folder_inside_destination?

      raise "Folder not found: #{folder}" unless File.directory?(folder)

      if download.tv?
        file = File.join(folder, download.output_name.to_s)
        raise "File not found: #{file}" if download.output_name.blank? || !File.exist?(file)

        FileUtils.rm_f([file, "#{file}.aria2"])
        prune_empty_folders(download)
      else
        FileUtils.rm_rf(folder)
      end
    end

    SYNC_LOCK = Mutex.new
    SYNC_INTERVAL = 1.0 # seconds; several open tabs/phones share one sync
    @last_sync_at = 0.0
    class << self
      attr_accessor :last_sync_at
    end

    # Copies status/progress/speed from aria2 into the database, and restarts
    # downloads whose retry wait is over.
    # Only one thread syncs at a time, at most once a second, and all rows are
    # written in one transaction, so SQLite never has several writers queueing.
    def sync(downloads)
      return unless SYNC_LOCK.try_lock # another request is syncing right now

      begin
        now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        return if now - self.class.last_sync_at < SYNC_INTERVAL

        self.class.last_sync_at = now
        update_from_aria2(downloads)
        retry_due_downloads
      ensure
        SYNC_LOCK.unlock
      end
    rescue Aria2Client::Error => e
      Rails.logger.warn("aria2 sync failed: #{e.message}")
    end

    private

    # Per-download connection count: ARIA2_CONNECTIONS, halved on the first automatic retries.
    def connections_for(download)
      base = ENV.fetch("ARIA2_CONNECTIONS", 16).to_i.clamp(1, 16)
      [base >> download.retries.to_i.clamp(0, 2), 1].max # never below a quarter
    end

    def add(download, output_name)
      connections = connections_for(download).to_s
      @client.add_uri(
        download.url,
        "dir" => download.folder_path,
        "out" => output_name,
        "max-connection-per-server" => connections,
        "split" => connections,
        "follow-torrent" => "false",
        "follow-metalink" => "false"
      )
    end

    def update_from_aria2(downloads)
      tracked = Array(downloads).select { |d| d.gid.present? && d.status.in?(%w[pending downloading paused]) }
      return if tracked.empty?

      results = @client.multicall(tracked.map { |d| ["aria2.tellStatus", d.gid, SYNC_KEYS] })
      finished_gids = []
      Download.transaction do
        tracked.zip(results).each do |download, result|
          old_gid = download.gid
          apply(download, result)
          finished_gids << old_gid if download.gid.nil? # queued for a retry
        end
      end
      # Outside the transaction: talking to aria2 must not hold the database lock.
      finished_gids.each { |gid| @client.call("aria2.removeDownloadResult", gid) rescue nil }
    end

    # Downloads waiting for a retry are "pending" with no aria2 gid.
    def retry_due_downloads
      Download.where(status: "pending", gid: nil).where("retries > 0").find_each do |download|
        next if download.updated_at > backoff_for(download).seconds.ago

        gid = add(download, download.output_name)
        download.update!(gid: gid, error_message: nil)
        Rails.logger.info("Download #{download.id}: retry #{download.retries} " \
                          "with #{connections_for(download)} connections")
      end
    end

    # 15s, 30s, 60s... capped, plus a few seconds per download so queued
    # retries don't all hit the server in the same second.
    def backoff_for(download)
      [15 * 2**(download.retries.to_i - 1), MAX_BACKOFF].min + (download.id.to_i % 5) * 3
    end

    def throttled?(download, error)
      error.to_s.match?(THROTTLED) && download.retries.to_i < MAX_AUTO_RETRIES && download.output_name.present?
    end

    def apply(download, result)
      if result.is_a?(Aria2Client::Error)
        download.update!(status: "failed", download_speed: 0,
                         error_message: "aria2 no longer knows this download (was it restarted?). Press Resume to start it again.")
        return
      end

      total = result["totalLength"].to_i
      done = result["completedLength"].to_i
      attrs = {
        status: STATUS_MAP.fetch(result["status"], download.status),
        download_speed: result["downloadSpeed"].to_i,
        file_size: total.positive? ? total : download.file_size
      }
      attrs[:progress] = (done.to_f / total * 100).round(2) if total.positive?
      attrs[:progress] = 100 if attrs[:status] == "completed"
      attrs[:download_speed] = 0 unless attrs[:status] == "downloading"
      attrs[:error_message] = result["errorMessage"] if attrs[:status] == "failed"

      if attrs[:status] == "failed" && throttled?(download, attrs[:error_message])
        download.retries += 1
        attrs.merge!(status: "pending", gid: nil, error_message:
          "Server is busy (HTTP #{attrs[:error_message][THROTTLED, 1]}). " \
          "Trying again in #{backoff_for(download)}s.")
      end
      download.update!(attrs)
    end

    # Size, type and file name of the link. Some servers refuse HEAD requests,
    # so fall back to asking for the first byte (the reply carries the total size).
    def probe(url)
      head = request_headers(url, Net::HTTP::Head) || {}
      return head if head[:size].to_i.positive?

      ranged = request_headers(url, Net::HTTP::Get, { "Range" => "bytes=0-0" }) || {}
      { size: ranged[:size], type: head[:type] || ranged[:type], disposition: head[:disposition] || ranged[:disposition] }
    end

    # Reads only the response headers (never the body, so a server that ignores
    # the Range header cannot make us download the whole file). Follows redirects.
    def request_headers(url, verb, extra = {}, redirects: 5)
      uri = URI(url)
      Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: 8, read_timeout: 8) do |http|
        req = verb.new(uri)
        extra.each { |k, v| req[k] = v }
        http.request(req) do |res|
          if res.is_a?(Net::HTTPRedirection) && res["location"] && redirects.positive?
            return request_headers(URI.join(url, res["location"]).to_s, verb, extra, redirects: redirects - 1)
          end
          return nil unless res.is_a?(Net::HTTPSuccess)

          total = res["content-range"].to_s[%r{/(\d+)\z}, 1]
          size = total ? total.to_i : (res.is_a?(Net::HTTPPartialContent) ? nil : res["content-length"]&.to_i)
          return { size: size, type: res["content-type"], disposition: res["content-disposition"] }
        end
      end
    rescue StandardError => e
      Rails.logger.info("#{verb.name.demodulize} #{url} failed: #{e.message}")
      nil
    end

    def wait_until_stopped(gid)
      10.times do
        status = @client.call("aria2.tellStatus", gid, ["status"])["status"]
        return if status.in?(%w[removed complete error])

        sleep 0.3
      end
    end

    def remove_partial_files(download)
      return if download.output_name.blank? || !download.folder_inside_destination?

      file = File.join(download.folder_path, download.output_name)
      FileUtils.rm_f([file, "#{file}.aria2"])
      prune_empty_folders(download)
    rescue SystemCallError => e
      Rails.logger.warn("Could not clean up #{download.folder_path}: #{e.message}")
    end

    # Removes the download's folder, then (for TV) the show folder, if empty.
    # Never goes above the destination folder itself.
    def prune_empty_folders(download)
      base = File.expand_path(download.destination_path)
      dir = File.expand_path(download.folder_path)
      while dir.start_with?("#{base}/") && Dir.exist?(dir) && Dir.empty?(dir)
        Dir.rmdir(dir)
        dir = File.dirname(dir)
      end
    end
  end
end
