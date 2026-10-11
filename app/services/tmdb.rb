# Minimal client for The Movie Database (posters, overviews, seasons).
# https://developer.themoviedb.org/reference/intro/getting-started
#
# Set TMDB_API_KEY in .env to either the "API Key" (v3, short) or the
# "API Read Access Token" (v4, long). Without it, search and artwork are off
# and titles can still be added by name.
module Tmdb
  class Error < StandardError; end

  BASE = "https://api.themoviedb.org/3".freeze
  IMAGE_BASE = "https://image.tmdb.org/t/p".freeze

  module_function

  def enabled?
    key.present?
  end

  def image_url(path, size = "w342")
    "#{IMAGE_BASE}/#{size}#{path}" if path.present?
  end

  # Movies and TV shows matching a query, best matches first.
  def search(query)
    results = get("/search/multi", query: query, include_adult: false)["results"] || []
    results.select { |r| r["media_type"].in?(%w[movie tv]) }.map { |r| normalize(r, r["media_type"]) }
  end

  # Best single match for a download name like "Panchayat" (2020, tv).
  def find(name, media_type, year: nil)
    params = { query: name, include_adult: false }
    params[media_type == "tv" ? :first_air_date_year : :year] = year if year
    results = get("/search/#{media_type}", **params)["results"] || []
    # A year filter can be too strict (release vs. upload year): retry without it.
    results = get("/search/#{media_type}", query: name, include_adult: false)["results"] || [] if results.empty? && year
    results.first && normalize(results.first, media_type)
  end

  # Full details in one request: seasons (TV), runtime, genres, cast,
  # director/creators, trailer, recommendations and the IMDb/Wikidata ids.
  def details(media_type, tmdb_id)
    data = get("/#{media_type}/#{tmdb_id}", append_to_response: "credits,videos,recommendations,external_ids")
    info = normalize(data, media_type)
    ids = data["external_ids"] || {}
    info[:imdb_id] = data["imdb_id"].presence || ids["imdb_id"].presence
    info[:runtime] = media_type == "tv" ? Array(data["episode_run_time"]).first : data["runtime"]
    info[:runtime] = nil unless info[:runtime].to_i.positive?
    info[:genres] = Array(data["genres"]).map { |g| g["name"] }.join(", ").presence
    info[:tmdb_rating] = data["vote_average"].to_f.round(1) if data["vote_count"].to_i >= 20
    info[:details] = {
      "tagline" => data["tagline"].presence,
      "directors" => directors(data, media_type),
      "cast" => Array(data.dig("credits", "cast")).first(10).map do |c|
        { "name" => c["name"], "character" => c["character"].presence, "photo" => c["profile_path"] }
      end,
      "trailer" => trailer_key(data),
      "recommendations" => Array(data.dig("recommendations", "results")).first(12).map { |r| normalize(r, r["media_type"] || media_type).slice(:tmdb_id, :media_type, :name, :year, :poster_path).transform_keys(&:to_s) },
      "wikidata_id" => ids["wikidata_id"].presence,
      "tmdb_url" => "https://www.themoviedb.org/#{media_type}/#{tmdb_id}"
    }
    if media_type == "tv"
      info[:seasons] = Array(data["seasons"]).map do |s|
        { number: s["season_number"], episode_count: s["episode_count"], air_date: parse_date(s["air_date"]) }
      end
    end
    info
  end

  # Lists for the Discover page.
  def trending
    (get("/trending/all/week")["results"] || []).select { |r| r["media_type"].in?(%w[movie tv]) }
                                                 .map { |r| normalize(r, r["media_type"]) }
  end

  def upcoming_movies
    (get("/movie/upcoming")["results"] || []).map { |r| normalize(r, "movie") }
  end

  def popular_hindi
    (get("/discover/movie", with_original_language: "hi", sort_by: "popularity.desc")["results"] || [])
      .map { |r| normalize(r, "movie") }
  end

  def directors(data, media_type)
    if media_type == "tv"
      Array(data["created_by"]).map { |c| c["name"] }
    else
      Array(data.dig("credits", "crew")).select { |c| c["job"] == "Director" }.map { |c| c["name"] }.uniq
    end
  end

  # Official YouTube trailer first, then any trailer, then a teaser.
  def trailer_key(data)
    videos = Array(data.dig("videos", "results")).select { |v| v["site"] == "YouTube" }
    pick = videos.find { |v| v["type"] == "Trailer" && v["official"] } ||
           videos.find { |v| v["type"] == "Trailer" } || videos.find { |v| v["type"] == "Teaser" }
    pick && pick["key"]
  end

  def normalize(r, media_type)
    date = parse_date(media_type == "tv" ? r["first_air_date"] : r["release_date"])
    {
      tmdb_id: r["id"],
      media_type: media_type,
      name: r["title"] || r["name"],
      original_name: r["original_title"] || r["original_name"],
      original_language: r["original_language"],
      release_date: date,
      year: date&.year,
      poster_path: r["poster_path"],
      backdrop_path: r["backdrop_path"],
      overview: r["overview"].presence
    }
  end

  def parse_date(text)
    Date.iso8601(text) if text.present?
  rescue Date::Error
    nil
  end

  def key
    ENV["TMDB_API_KEY"].to_s.strip
  end

  def get(path, **params)
    raise Error, "TMDB_API_KEY is not set" unless enabled?

    headers = { "Accept" => "application/json" }
    # v4 tokens are long JWTs; v3 keys are 32 hex characters.
    if key.length > 40
      headers["Authorization"] = "Bearer #{key}"
    else
      params[:api_key] = key
    end
    res = HTTParty.get("#{BASE}#{path}", query: params, headers: headers, timeout: 8)
    raise Error, "TMDB answered HTTP #{res.code}" unless res.code.to_i == 200

    res.parsed_response
  rescue HTTParty::Error, SocketError, Timeout::Error, Errno::ECONNREFUSED, Net::OpenTimeout, Net::ReadTimeout => e
    raise Error, "TMDB is not reachable (#{e.class.name.demodulize})"
  end
end
