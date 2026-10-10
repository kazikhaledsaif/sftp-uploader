# The list of places a download is allowed to go.
#
# Set DOWNLOAD_DESTINATIONS in .env as "Label=/path,Label=/path".
# Only these paths can be picked in the UI, so nobody can make the app
# write somewhere else on the server.
module Destinations
  # Folders inside MEDIA_ROOT (mounted at /data). Movies/TV are the Jellyfin libraries.
  DEFAULT = "Movies=/data/Movies,TV Series=/data/TV,Downloads=/data/Downloads".freeze

  module_function

  # => [["Movies", "/data/Movies"], ...]
  def all
    raw = ENV["DOWNLOAD_DESTINATIONS"].presence || DEFAULT
    raw.split(",").filter_map do |pair|
      label, path = pair.split("=", 2).map { |s| s.to_s.strip }
      [label, path] if label.present? && path.present?
    end
  end

  def paths
    all.map(&:last)
  end

  # TV folders get the Jellyfin layout: Show/Season 01/Show S01E02.mkv
  def tv?(path)
    label = all.find { |_, p| p.chomp("/") == path.to_s.chomp("/") }&.first
    label.to_s.match?(/\b(tv|series|shows?|serials?)\b/i) || path.to_s.match?(%r{/tv/?\z}i)
  end
end
