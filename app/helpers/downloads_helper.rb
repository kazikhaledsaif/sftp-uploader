module DownloadsHelper
  STATUS_LABELS = {
    "pending" => "Queued", "downloading" => "Downloading", "paused" => "Paused",
    "completed" => "Done", "failed" => "Failed", "cancelled" => "Cancelled"
  }.freeze

  HTTP_REASONS = {
    "403" => "the server refused access", "404" => "the file was not found",
    "410" => "the link has expired", "429" => "too many requests to this server",
    "503" => "the server is busy"
  }.freeze

  def status_label(download)
    STATUS_LABELS.fetch(download.status, download.status.humanize)
  end

  # "/data/Movies" -> "Movies" (the label shown under "Save to")
  def destination_label(download)
    Destinations.all.find { |_, path| path.chomp("/") == download.destination_path.chomp("/") }&.first ||
      File.basename(download.destination_path)
  end

  def display_name(download)
    download.filename.presence || File.basename(URI.parse(download.url).path)
  end

  # "Season 3", "Season 3, episodes 1-8" or "S03E02"
  def episode_label(download)
    return unless download.tv?
    return format("S%02dE%02d", download.season, download.episode) if download.kind == "episode"

    count = download.episode_count.to_i
    count > 1 ? "Season #{download.season}, episodes 1-#{count}" : "Season #{download.season}"
  end

  # aria2's messages are terse; turn the common HTTP ones into a sentence.
  def friendly_error(message)
    return "Stopped: the disk is full. Free up space, then press Retry." if message.to_s.match?(/no space|disk space|not enough space left/i)

    code = message.to_s[/status=(\d{3})/, 1]
    return message unless code

    reason = HTTP_REASONS[code]
    reason ? "Stopped: #{reason} (HTTP #{code})." : "Stopped: the server answered HTTP #{code}."
  end
end
