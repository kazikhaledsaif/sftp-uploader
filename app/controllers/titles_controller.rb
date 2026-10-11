class TitlesController < ApplicationController
  PER_PAGE = 48
  SORTS = {
    "added" => "Recently added", "release" => "Release date", "rating" => "Best rated",
    "short" => "Shortest first", "name" => "A to Z"
  }.freeze
  FILTER_KEYS = %i[type lang genre have q sort].freeze

  before_action :set_title, only: %i[show update destroy refresh]

  rescue_from ActiveRecord::RecordNotFound do
    redirect_to titles_path, alert: "That title is no longer on your watchlist."
  end

  # GET /watchlist  (what you still want to watch)
  def index
    @filters = params.permit(*FILTER_KEYS).to_h.symbolize_keys.compact_blank
    @overdue = Plan.overdue.includes(:title)
    @planned = Plan.upcoming.includes(:title).limit(8)
    @watching = Title.with_status("watching").includes(:seasons, :plans).order(updated_at: :desc)

    scope = filtered(Title.with_status("want"))
    @total = scope.count
    @page = [params[:page].to_i, 1].max
    @titles = scope.includes(:downloads, :seasons, :plans).offset((@page - 1) * PER_PAGE).limit(PER_PAGE + 1).to_a
    @more = @titles.size > PER_PAGE
    @titles = @titles.first(PER_PAGE)
    @genres = Title.with_status("want").pluck(:genres).compact.flat_map { |g| g.split(", ") }.tally
                   .sort_by { |g, n| [-n, g] }.first(12).map(&:first)
  end

  # GET /watchlist/pick  (random title from the Want list, same filters)
  def pick
    filters = params.permit(*FILTER_KEYS).to_h.symbolize_keys.compact_blank
    title = filtered(Title.with_status("want")).where.not(id: params[:not]).order(Arel.sql("RANDOM()")).first
    if title
      redirect_to title_path(title, picked: 1, **filters)
    else
      redirect_to titles_path(**filters), alert: "Nothing on your Want list matches. Add more titles first."
    end
  end

  # GET /discover?q=  (find new movies and series to add)
  def discover
    @query = params[:q].to_s.strip
    return search if @query.present?
    return unless Tmdb.enabled?

    @rows = {
      "Trending this week" => cached("trending") { Tmdb.trending },
      "Popular Hindi movies" => cached("hindi") { Tmdb.popular_hindi },
      "Coming soon" => cached("upcoming") { Tmdb.upcoming_movies }
    }
    liked = Viewing.where("rating >= 8").includes(:title).recent_first.limit(3).map(&:title).uniq
    liked.each do |t|
      recs = Array(t.detail(:recommendations)).map(&:symbolize_keys)
      @rows["Because you liked #{t.name}"] = recs if recs.any?
    end
    @tracked = tracked_for(@rows.values.flatten)
  rescue Tmdb::Error => e
    @error = e.message
  end

  def show
    RefreshTitleJob.perform_later(@title.id) if RefreshTitleJob.stale?(@title)
    @picked = params[:picked].present?
    @pick_filters = params.permit(*FILTER_KEYS).to_h.symbolize_keys.compact_blank
  end

  # POST /watchlist  (from a search result, or typed by hand)
  def create
    status = %w[want watched].include?(params[:status]) ? params[:status] : "want"
    title = if params[:tmdb_id].present?
              Tracker.add_from_tmdb(media_type_param, params[:tmdb_id].to_i, status: status)
            else
              Tracker.add_by_name(params[:name], media_type_param, status: status)
            end
    message = status == "watched" ? "#{title.name} is in your diary." : "#{title.name} is on your Want list."
    redirect_back_to(params[:return_to], notice: message, fallback: title_path(title))
  rescue Tmdb::Error, ActiveRecord::RecordInvalid => e
    redirect_back_to(params[:return_to], alert: "Could not add it: #{e.message}", fallback: titles_path)
  end

  # PATCH /watchlist/:id  status=want (move back to the Want list)
  def update
    @title.mark!(params[:status]) if Title::STATUSES.include?(params[:status])
    redirect_to title_path(@title)
  end

  def destroy
    @title.destroy
    redirect_to titles_path, notice: "#{@title.name} was removed."
  end

  # POST /watchlist/:id/refresh  (fetch artwork and details again)
  def refresh
    found = Tracker.refresh_details(@title)
    Extras.apply(@title.reload)
    redirect_to title_path(@title), notice: found ? "Artwork and details updated." : "TMDB has no match for this name."
  rescue Tmdb::Error => e
    redirect_to title_path(@title), alert: e.message
  end

  private

  def set_title
    @title = Title.includes(:seasons, :downloads, :plans, viewings: :title).find(params[:id])
  end

  def filtered(scope)
    f = params
    scope = scope.where(media_type: f[:type]) if f[:type].in?(Title::MEDIA_TYPES)
    case f[:lang]
    when "hi", "en" then scope = scope.where(original_language: f[:lang])
    when "other" then scope = scope.where.not(original_language: %w[hi en]).or(scope.where(original_language: nil))
    end
    scope = scope.where("genres LIKE ?", "%#{Title.sanitize_sql_like(f[:genre])}%") if f[:genre].present?
    downloaded = Download.where(status: "completed").select(:title_id)
    scope = scope.where(id: downloaded) if f[:have] == "library"
    scope = scope.where.not(id: downloaded) if f[:have] == "missing"
    scope = scope.where("lower(name) LIKE ?", "%#{Title.sanitize_sql_like(f[:q].downcase)}%") if f[:q].present?
    case f[:sort]
    when "release" then scope.order(Arel.sql("release_date IS NULL, release_date DESC"))
    when "rating" then scope.order(Arel.sql("tmdb_rating IS NULL, tmdb_rating DESC"))
    when "short" then scope.order(Arel.sql("runtime IS NULL, runtime ASC"))
    when "name" then scope.order(Arel.sql("lower(name)"))
    else scope.order(created_at: :desc)
    end
  end

  def media_type_param
    Title::MEDIA_TYPES.include?(params[:media_type]) ? params[:media_type] : "movie"
  end

  def search
    return @error = "Add TMDB_API_KEY to .env to search with posters. You can still add by name." unless Tmdb.enabled?

    @results = Tmdb.search(@query)
    @tracked = tracked_for(@results)
  rescue Tmdb::Error => e
    @results = []
    @error = e.message
  end

  def tracked_for(items)
    Title.where(tmdb_id: items.map { |r| r[:tmdb_id] }).index_by { |t| [t.media_type, t.tmdb_id] }
  end

  # TMDB lists change slowly; cache them for a few hours.
  def cached(key, &block)
    Rails.cache.fetch("tmdb/#{key}", expires_in: 6.hours, &block)
  end

  # Only local paths, so a crafted link cannot redirect off the site.
  def redirect_back_to(path, fallback:, **flash)
    target = path.to_s.start_with?("/") && !path.to_s.start_with?("//") ? path : fallback
    redirect_to target, **flash
  end
end
