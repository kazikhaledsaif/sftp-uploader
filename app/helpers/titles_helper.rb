module TitlesHelper
  LANGUAGES = { "hi" => "Hindi", "en" => "English", "ta" => "Tamil", "te" => "Telugu", "ml" => "Malayalam",
                "bn" => "Bengali", "mr" => "Marathi", "pa" => "Punjabi", "kn" => "Kannada", "ko" => "Korean",
                "ja" => "Japanese", "es" => "Spanish", "fr" => "French" }.freeze

  # Poster image, or a quiet placeholder when there is no artwork.
  # item: a Title or a TMDB search result hash.
  def poster(item, size: "w342", css: "poster")
    path = item.is_a?(Hash) ? item[:poster_path] : item.poster_path
    name = item.is_a?(Hash) ? item[:name] : item.name
    if (src = Tmdb.image_url(path, size))
      image_tag src, alt: "", class: css, loading: "lazy", decoding: "async"
    else
      tag.span(class: "#{css} poster-empty", "aria-hidden": true) { tag.i(class: "ph ph-film-slate") + tag.span(name.to_s.first) }
    end
  end

  def language_name(code)
    LANGUAGES[code] || code.to_s.upcase.presence
  end

  # "Movie  2016  Hindi"
  def title_meta(item)
    type = (item.is_a?(Hash) ? item[:media_type] : item.media_type) == "tv" ? "TV series" : "Movie"
    year = item.is_a?(Hash) ? item[:year] : item.year
    lang = language_name(item.is_a?(Hash) ? item[:original_language] : item.original_language)
    [type, year, lang].compact
  end

  def release_note(title)
    return unless title.upcoming?

    "Out #{title.release_date.strftime(title.release_date.year == Date.current.year ? '%-d %b' : '%-d %b %Y')}"
  end

  # "Next: S3, 2 left" for a show you are part-way through.
  def seasons_left_note(title)
    return unless title.tv? && title.status != "watched"

    left = title.seasons_left
    return if left.empty? || left.size == title.seasons.size # nothing watched yet

    left.size == 1 ? "Next: S#{left.first.number}, last one" : "Next: S#{left.first.number}, #{left.size} left"
  end

  # Read-only stars for a half-star rating (1..10).
  def stars(rating, css: "stars")
    return "".html_safe unless rating

    full, half = rating.divmod(2)
    icons = Array.new(full) { tag.i(class: "ph-fill ph-star") }
    icons << tag.i(class: "ph-fill ph-star-half") if half == 1
    icons.concat(Array.new(5 - full - half) { tag.i(class: "ph ph-star") })
    tag.span(safe_join(icons), class: css, title: "#{rating / 2.0} of 5", "aria-label": "#{rating / 2.0} of 5 stars")
  end

  def runtime_text(minutes)
    return unless minutes.to_i.positive?

    h, m = minutes.divmod(60)
    h.zero? ? "#{m}m" : "#{h}h #{format('%02dm', m)}"
  end

  # [[label, value], ...] for the critic score row (only scores we have).
  def scores(title)
    [
      ["TMDB", title.tmdb_rating&.then { |r| format("%.1f", r) }],
      ["IMDb", title.detail(:imdb_rating)],
      ["Rotten Tomatoes", title.detail(:rotten_tomatoes)],
      ["Metacritic", title.detail(:metacritic)]
    ].select(&:last)
  end

  # Quick choices for "Plan": Tonight, Tomorrow, and the coming Fri/Sat/Sun.
  def plan_choices
    today = Date.current
    choices = [["Tonight", today], ["Tomorrow", today + 1]]
    [5, 6, 0].each do |wday| # Fri, Sat, Sun
      date = today + ((wday - today.wday) % 7)
      next if date <= today + 1

      choices << ["#{date.strftime('%a')} night", date]
    end
    choices
  end

  def short_date(date)
    return "" unless date

    fmt = date.year == Date.current.year ? "%a %-d %b" : "%-d %b %Y"
    date.strftime(fmt)
  end

  def relative_day(date)
    case (date - Date.current).to_i
    when 0 then "Tonight"
    when 1 then "Tomorrow"
    else short_date(date)
    end
  end

  def profile_url(path)
    Tmdb.image_url(path, "w185")
  end

  def share_text(title)
    link = title.imdb_id ? "https://www.imdb.com/title/#{title.imdb_id}/" : title.detail(:tmdb_url)
    ["#{title.name}#{" (#{title.year})" if title.year}", link].compact.join(" ")
  end

  # Link that opens the download form ready for this title.
  def download_link_for(title, season: nil)
    params = { name: title.folder_name, media: title.media_type }
    params[:season] = season if season
    root_path(params)
  end
end
