# Adds a just-started download to the watchlist (TMDB lookups are slow, so
# this runs in the background and never delays the download itself).
class TrackDownloadJob < ApplicationJob
  def perform(download_id)
    download = Download.find_by(id: download_id)
    Tracker.track_download(download) if download
  end
end
