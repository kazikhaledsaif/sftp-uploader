class Title < ApplicationRecord
  MEDIA_TYPES = %w[movie tv].freeze
  STATUSES = %w[want watching watched].freeze
  STATUS_LABELS = { "want" => "Want to watch", "watching" => "Watching", "watched" => "Watched" }.freeze

  has_many :seasons, -> { order(:number) }, class_name: "TitleSeason", dependent: :destroy
  has_many :viewings, dependent: :destroy
  has_many :plans, dependent: :destroy
  has_many :downloads, dependent: :nullify

  validates :name, presence: true
  validates :media_type, inclusion: { in: MEDIA_TYPES }
  validates :status, inclusion: { in: STATUSES }

  scope :with_status, ->(status) { where(status: status) }

  def tv?
    media_type == "tv"
  end

  def status_label
    STATUS_LABELS.fetch(status)
  end

  def upcoming?
    release_date.present? && release_date > Date.current
  end

  def downloaded?
    downloads.any?(&:completed?)
  end

  # Hindi (and other) titles: show the original script when it differs.
  def alternate_name
    original_name if original_name.present? && original_name != name
  end

  # Name the download form should use, matching how the folder is named.
  def folder_name
    year ? "#{name} (#{year})" : name
  end

  def genre_list
    genres.to_s.split(",").map(&:strip).reject(&:empty?)
  end

  def detail(key)
    (details || {})[key.to_s]
  end

  # Latest rating from the diary (half stars, 1..10).
  def my_rating
    viewings.select(&:rating).max_by { |v| [v.watched_on, v.created_at] }&.rating
  end

  def next_plan
    plans.select { |p| p.planned_on >= Date.current }.min_by(&:planned_on)
  end

  # Seasons still to watch, in order.
  def seasons_left
    tv? ? seasons.reject(&:watched?) : []
  end

  def season(number)
    seasons.find { |s| s.number == number } || seasons.create!(number: number)
  end

  # Adds diary entries. Movies: one entry. TV: one entry per season given,
  # or for every season not watched yet. Plans for what was watched are done.
  def log_watch!(on: Date.current, rating: nil, note: nil, season_numbers: nil)
    on = on.presence || Date.current
    transaction do
      if tv?
        numbers = Array(season_numbers).map(&:to_i).presence || seasons_left.map(&:number)
        if numbers.empty? # a show with no known seasons: one entry for the whole show
          viewings.create!(watched_on: on, rating: rating, note: note)
          plans.destroy_all
          update!(status: "watched", watched_on: [watched_on, on].compact.max)
        else
          numbers.each do |n|
            viewings.create!(season_number: n, watched_on: on, rating: rating, note: note)
            season(n).update!(status: "watched", watched_on: on)
          end
          plans.where(season_number: [nil, *numbers]).destroy_all
          refresh_from_seasons!
        end
      else
        viewings.create!(watched_on: on, rating: rating, note: note)
        plans.destroy_all
        update!(status: "watched", watched_on: [watched_on, on].compact.max)
      end
    end
  end

  def unwatch_season!(number)
    transaction do
      season(number).update!(status: "want", watched_on: nil)
      viewings.where(season_number: number).destroy_all
      refresh_from_seasons!
    end
  end

  # Status picker: "watched" logs a diary entry for today.
  def mark!(new_status, on: Date.current)
    if new_status == "watched"
      log_watch!(on: on) unless status == "watched"
    else
      update!(status: new_status)
    end
  end

  # Status of a show follows its seasons: none / some / all watched.
  def refresh_from_seasons!
    return unless tv? && seasons.reload.any?

    watched = seasons.select(&:watched?)
    new_status = if watched.size == seasons.size then "watched"
                 elsif watched.any? then "watching"
                 else "want"
                 end
    update!(status: new_status, watched_on: watched.filter_map(&:watched_on).max)
  end

  # "Dangal (2016)" -> ["Dangal", 2016]
  def self.split_year(text)
    m = text.to_s.strip.match(/\A(.*?)\s*\((\d{4})\)\z/)
    m ? [m[1], m[2].to_i] : [text.to_s.strip, nil]
  end
end
