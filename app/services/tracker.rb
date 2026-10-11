# Puts movies and shows on the watchlist: from TMDB search results, from a
# typed name, or automatically when something is downloaded.
module Tracker
  module_function

  # From a TMDB search result the user tapped. Returns the Title.
  def add_from_tmdb(media_type, tmdb_id, status:)
    title = Title.find_by(media_type: media_type, tmdb_id: tmdb_id)
    return title if title

    info = Tmdb.details(media_type, tmdb_id)
    title = Title.new(media_type: media_type)
    apply_details(title, info)
    title.mark!(status) unless status == "want" # watched: a diary entry (every season for a show)
    RefreshTitleJob.perform_later(title.id, tmdb: false) # scores and Wikipedia summary
    title
  end

  # Typed in by hand (or TMDB is off): "Dangal (2016)". Reuses a title
  # already on the list (same name, or the same TMDB entry).
  def add_by_name(text, media_type, status:)
    name, year = Title.split_year(text)
    existing = find_by_name(name, media_type, year)
    return existing if existing

    match = tmdb_match(name, media_type, year)
    if match
      Title.find_by(media_type: media_type, tmdb_id: match[:tmdb_id]) ||
        add_from_tmdb(media_type, match[:tmdb_id], status: status)
    else
      create_plain(name, year, media_type, status)
    end
  rescue Tmdb::Error => e
    Rails.logger.warn("TMDB lookup for #{name.inspect} failed: #{e.message}")
    create_plain(name, year, media_type, status)
  end

  def create_plain(name, year, media_type, status)
    title = Title.create!(name: name, year: year, media_type: media_type)
    title.mark!(status) unless status == "want"
    title
  end

  # Called (in the background) after a download starts: puts the movie or
  # show on the list as "want to watch" (if it is not there already) and, for
  # TV, adds the downloaded season.
  def track_download(download)
    media_type = download.tv? ? "tv" : "movie"
    title = add_by_name(download.filename, media_type, status: "want")
    download.update!(title: title)

    if title.tv?
      season = title.season(download.season.to_i)
      season.update!(episode_count: season.episode_count || download.episode_count)
      title.refresh_from_seasons! # a new unwatched season moves a watched show back to watching
    end
    title
  end

  # Artwork/overview for a title added while TMDB was off or unreachable.
  def refresh_details(title)
    match = title.tmdb_id ? { tmdb_id: title.tmdb_id } : tmdb_match(title.name, title.media_type, title.year)
    return false unless match
    return false if Title.where.not(id: title.id).exists?(media_type: title.media_type, tmdb_id: match[:tmdb_id])

    apply_details(title, Tmdb.details(title.media_type, match[:tmdb_id]))
    true
  end

  def tmdb_match(name, media_type, year)
    Tmdb.enabled? ? Tmdb.find(name, media_type, year: year) : nil
  end

  def apply_details(title, info)
    title.assign_attributes(info.except(:seasons, :media_type, :details).compact)
    title.details = (title.details || {}).merge(info[:details] || {})
    title.details_fetched_at = Time.current if info[:details]
    title.save!
    Array(info[:seasons]).each do |s|
      next if s[:number].to_i.zero? # skip "Specials"
      season = title.seasons.find_or_initialize_by(number: s[:number])
      season.update!(episode_count: s[:episode_count], air_date: s[:air_date])
    end
  end

  # Same show/movie already on the list? Match on name (and year if known).
  def find_by_name(name, media_type, year)
    scope = Title.where(media_type: media_type).where("lower(name) = ?", name.downcase)
    (year && scope.find_by(year: year)) || scope.first
  end
end
