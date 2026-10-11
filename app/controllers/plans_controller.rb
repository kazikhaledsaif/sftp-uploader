# Planned watches and the calendar of what is coming up.
class PlansController < ApplicationController
  # GET /calendar?month=2026-10
  def index
    @month = begin
      Date.strptime(params[:month].to_s, "%Y-%m")
    rescue Date::Error
      Date.current.beginning_of_month
    end
    range = @month.beginning_of_month.beginning_of_week(:monday)..@month.end_of_month.end_of_week(:monday)

    # Every day in view -> [[kind, title, label], ...]  (planned first, then releases, then watched)
    events = Plan.includes(:title).where(planned_on: range).map { |p| [p.planned_on, :plan, p.title, p.label] } +
             Title.where(status: "want", release_date: range).map { |t| [t.release_date, :release, t, t.name] } +
             Viewing.includes(:title).where(watched_on: range).map { |v| [v.watched_on, :watched, v.title, v.label] }
    order = { plan: 0, release: 1, watched: 2 }
    @events = events.group_by(&:first).transform_values { |list| list.sort_by { |e| order[e[1]] }.map { |e| e.drop(1) } }
    @days = range.to_a
    @selected = @events.key?(Date.current) || @month.month == Date.current.month ? Date.current : (@events.keys.min || @month)

    @overdue = Plan.overdue.includes(:title)
    @upcoming = (Plan.upcoming.includes(:title).limit(30).map { |p| [p.planned_on, :plan, p] } +
                 Title.where(status: "want").where("release_date > ?", Date.current).order(:release_date)
                      .limit(30).map { |t| [t.release_date, :release, t] })
                .sort_by(&:first).first(30)
  end

  # POST /watchlist/:title_id/plans
  def create
    title = Title.find(params[:title_id])
    date = Date.iso8601(params[:planned_on].to_s)
    title.plans.where(season_number: params[:season_number].presence).destroy_all # one plan per title/season
    title.plans.create!(planned_on: date, season_number: params[:season_number].presence)
    redirect_to title_path(title), notice: "Planned for #{date.strftime('%a %-d %b')}."
  rescue Date::Error
    redirect_to title_path(title), alert: "Pick a date for the plan."
  end

  # DELETE /plans/:id
  def destroy
    plan = Plan.find_by(id: params[:id])
    plan&.destroy
    target = params[:return_to].to_s
    redirect_to(target.start_with?("/") && !target.start_with?("//") ? target : calendar_path,
                notice: "Plan removed.")
  end
end
