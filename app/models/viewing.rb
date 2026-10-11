# One entry in the diary: a movie, or a whole TV season, watched on a date.
class Viewing < ApplicationRecord
  belongs_to :title

  validates :watched_on, presence: true
  validates :rating, numericality: { only_integer: true, in: 1..10 }, allow_nil: true

  scope :recent_first, -> { order(watched_on: :desc, created_at: :desc) }

  def stars
    rating && rating / 2.0
  end

  def label
    season_number ? "#{title.name}, Season #{season_number}" : title.name
  end

  # Minutes this viewing took, if known (movie runtime, or episodes x runtime).
  def minutes
    return title.runtime if season_number.nil?

    season = title.seasons.find { |s| s.number == season_number }
    title.runtime && season&.episode_count ? title.runtime * season.episode_count : nil
  end
end
