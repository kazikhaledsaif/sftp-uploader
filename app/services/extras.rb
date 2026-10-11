# Extra movie info from free public APIs, stored in Title#details:
#   - OMDb (needs a free OMDB_API_KEY): IMDb rating, Rotten Tomatoes, Metacritic
#   - Wikipedia (no key): a short "about" summary and a link to the article
# Every source is optional; a failure just leaves that part out.
module Extras
  module_function

  def apply(title)
    found = {}
    found.merge!(omdb(title.imdb_id)) if title.imdb_id.present? && ENV["OMDB_API_KEY"].present?
    found.merge!(wikipedia(title.detail(:wikidata_id))) if title.detail(:wikidata_id).present?
    return if found.empty?

    title.update!(details: (title.details || {}).merge(found))
  end

  def omdb(imdb_id)
    res = HTTParty.get("https://www.omdbapi.com/", query: { i: imdb_id, apikey: ENV["OMDB_API_KEY"] }, timeout: 8)
    data = res.parsed_response
    return {} unless res.code == 200 && data.is_a?(Hash) && data["Response"] == "True"

    ratings = Array(data["Ratings"]).to_h { |r| [r["Source"], r["Value"]] }
    {
      "imdb_rating" => na(data["imdbRating"]),
      "imdb_votes" => na(data["imdbVotes"]),
      "rotten_tomatoes" => ratings["Rotten Tomatoes"],
      "metacritic" => na(data["Metascore"]),
      "awards" => na(data["Awards"])
    }.compact
  rescue StandardError => e
    Rails.logger.info("OMDb lookup for #{imdb_id} failed: #{e.message}")
    {}
  end

  # OMDb uses "N/A" for missing values.
  def na(value)
    value.presence unless value == "N/A"
  end

  # Wikidata id (from TMDB) -> English Wikipedia article -> summary.
  def wikipedia(wikidata_id)
    entity = HTTParty.get("https://www.wikidata.org/w/api.php",
                          query: { action: "wbgetentities", ids: wikidata_id, props: "sitelinks",
                                   sitefilter: "enwiki", format: "json" },
                          headers: { "User-Agent" => "Popcorn/1.0 (self-hosted watchlist)" }, timeout: 8)
    page = entity.parsed_response.dig("entities", wikidata_id, "sitelinks", "enwiki", "title")
    return {} if page.blank?

    summary = HTTParty.get("https://en.wikipedia.org/api/rest_v1/page/summary/#{ERB::Util.url_encode(page.tr(' ', '_'))}",
                           headers: { "User-Agent" => "Popcorn/1.0 (self-hosted watchlist)" }, timeout: 8)
    data = summary.parsed_response
    return {} unless summary.code == 200 && data.is_a?(Hash)

    { "wiki_summary" => data["extract"].presence,
      "wiki_url" => data.dig("content_urls", "mobile", "page") || data.dig("content_urls", "desktop", "page") }.compact
  rescue StandardError => e
    Rails.logger.info("Wikipedia lookup for #{wikidata_id} failed: #{e.message}")
    {}
  end
end
