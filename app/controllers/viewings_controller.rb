# The diary: every movie and TV season you watched, newest first.
class ViewingsController < ApplicationController
  PER_PAGE = 60

  rescue_from ActiveRecord::RecordNotFound do
    redirect_to diary_path, alert: "That diary entry no longer exists."
  end

  # GET /diary?year=2026&type=movie&view=list&page=2
  def index
    all = Viewing.joins(:title)
    @years = all.distinct.pluck(Arel.sql("strftime('%Y', viewings.watched_on)")).map(&:to_i).sort.reverse
    @year = params[:year].to_i if @years.include?(params[:year].to_i)
    @type = params[:type].presence_in(%w[movie tv])
    @view = params[:view] == "list" ? "list" : "grid"

    scope = all.includes(title: :seasons)
    scope = scope.where(watched_on: Date.new(@year)..Date.new(@year).end_of_year) if @year
    scope = scope.where(titles: { media_type: @type }) if @type
    @stats = stats(scope)

    @page = [params[:page].to_i, 1].max
    @viewings = scope.recent_first.offset((@page - 1) * PER_PAGE).limit(PER_PAGE + 1).to_a
    @more = @viewings.size > PER_PAGE
    @viewings = @viewings.first(PER_PAGE)
  end

  # POST /watchlist/:title_id/viewings  (the "Mark watched" sheet)
  def create
    title = Title.find(params[:title_id])
    title.log_watch!(on: parse_date(params[:watched_on]), rating: rating_param, note: params[:note].presence,
                     season_numbers: Array(params[:season_numbers]).reject(&:blank?))
    redirect_to title_path(title), notice: "Added to your diary."
  end

  # PATCH /diary/:id  (rating, note or date)
  def update
    viewing = Viewing.find(params[:id])
    attrs = {}
    attrs[:rating] = rating_param if params.key?(:rating)
    attrs[:note] = params[:note].presence if params.key?(:note)
    attrs[:watched_on] = parse_date(params[:watched_on]) if parse_date(params[:watched_on])
    viewing.update!(attrs)
    sync_title_dates(viewing.title, viewing.season_number)
    redirect_back_to(params[:return_to], fallback: title_path(viewing.title))
  end

  # DELETE /diary/:id
  def destroy
    viewing = Viewing.find(params[:id])
    title = viewing.title
    viewing.destroy
    if viewing.season_number && title.viewings.where(season_number: viewing.season_number).none?
      title.unwatch_season!(viewing.season_number)
    else
      sync_title_dates(title, viewing.season_number)
    end
    redirect_back_to(params[:return_to], fallback: title_path(title), notice: "Removed from your diary.")
  end

  private

  # Keep "last watched" dates (and a movie's status) in step with the diary.
  def sync_title_dates(title, season_number)
    if season_number
      latest = title.viewings.where(season_number: season_number).maximum(:watched_on)
      title.season(season_number).update!(watched_on: latest) if latest
      title.refresh_from_seasons!
    elsif title.viewings.none?
      title.update!(status: "want", watched_on: nil)
    else
      title.update!(watched_on: title.viewings.maximum(:watched_on))
    end
  end

  def stats(scope)
    rows = scope.to_a
    minutes = rows.sum { |v| v.minutes.to_i }
    rated = rows.filter_map(&:rating)
    genres = rows.flat_map { |v| v.title.genre_list }.tally.max_by(2) { |_, n| n }.map(&:first)
    { movies: rows.count { |v| v.season_number.nil? && !v.title.tv? },
      seasons: rows.count { |v| v.title.tv? },
      hours: (minutes / 60.0).round,
      average: rated.any? ? (rated.sum / rated.size / 2.0).round(1) : nil,
      genres: genres }
  end

  def parse_date(text)
    Date.iso8601(text.to_s)
  rescue Date::Error
    nil
  end

  def rating_param
    r = params[:rating].to_i
    r.between?(1, 10) ? r : nil
  end

  def redirect_back_to(path, fallback:, **flash)
    target = path.to_s.start_with?("/") && !path.to_s.start_with?("//") ? path : fallback
    redirect_to target, **flash
  end
end
