class TitleSeasonsController < ApplicationController
  # PATCH /watchlist/:title_id/seasons/:id
  #   status=watched  -> diary entry for the whole season (date optional)
  #   status=want     -> not watched (its diary entries are removed)
  #   watched_on only -> change the date
  def update
    title = Title.find(params[:title_id])
    season = title.seasons.find(params[:id])
    case params[:status]
    when "watched" then title.log_watch!(season_numbers: [season.number], on: parse_date(params[:watched_on]),
                                         rating: rating_param)
    when "want" then title.unwatch_season!(season.number)
    else
      if (date = parse_date(params[:watched_on]))
        season.update!(watched_on: date)
        title.viewings.where(season_number: season.number).order(:created_at).last&.update!(watched_on: date)
        title.refresh_from_seasons!
      end
    end
    redirect_to title_path(title, anchor: "season-#{season.number}")
  rescue ActiveRecord::RecordNotFound
    redirect_to titles_path, alert: "That season is no longer on your watchlist."
  end

  private

  def parse_date(text)
    Date.iso8601(text.to_s)
  rescue Date::Error
    nil
  end

  def rating_param
    r = params[:rating].to_i
    r.between?(1, 10) ? r : nil
  end
end
