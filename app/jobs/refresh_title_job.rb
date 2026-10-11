# Fetches (or refreshes) artwork, cast, trailer, scores and the Wikipedia
# summary for a title, in the background so pages stay fast.
class RefreshTitleJob < ApplicationJob
  STALE_AFTER = 14.days

  def self.stale?(title)
    Tmdb.enabled? && (title.details_fetched_at.nil? || title.details_fetched_at < STALE_AFTER.ago)
  end

  # tmdb: false when TMDB details were just fetched (only scores/Wikipedia needed).
  def perform(title_id, tmdb: true)
    title = Title.find_by(id: title_id)
    return unless title

    Tracker.refresh_details(title) if tmdb
    Extras.apply(title.reload)
  rescue Tmdb::Error => e
    Rails.logger.warn("Refreshing #{title&.name.inspect} failed: #{e.message}")
  ensure
    # Even on failure, wait STALE_AFTER before trying again.
    title&.update_columns(details_fetched_at: Time.current) if title&.persisted?
  end
end
