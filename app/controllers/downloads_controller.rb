class DownloadsController < ApplicationController
  before_action :set_download, only: %i[destroy pause resume cancel destroy_file]

  # A page left open can still show a download that was removed elsewhere.
  rescue_from ActiveRecord::RecordNotFound do
    redirect_to downloads_path, alert: "That download is no longer in the list. The page has been refreshed."
  end

  # GET /downloads
  def index
    DownloadEngine.current.sync(Download.active.to_a)
    @downloads = Download.recent
    @running, @history = @downloads.partition { |d| d.pending? || d.downloading? || d.paused? }
    @active_downloads = @running.size
    @completed_downloads = Download.completed.count
    @destinations = Destinations.all
  end

  # GET /downloads/status.json  (polled by the page every few seconds)
  def status
    DownloadEngine.current.sync(Download.active.to_a)
    render json: {
      active: Download.active.count,
      completed: Download.completed.count,
      downloads: Download.recent.limit(100).map(&:as_status_json)
    }
  end

  # POST /downloads
  def create
    @download = Download.new(download_params.merge(status: "pending"))

    if @download.save
      @download.start!
      respond_to do |format|
        format.json { render json: { id: @download.id, status: @download.status }, status: :created }
        format.html { redirect_to downloads_path, notice: "Download started." }
      end
    else
      respond_to do |format|
        format.json { render json: { errors: @download.errors.full_messages.to_sentence }, status: :unprocessable_entity }
        format.html { redirect_to downloads_path, alert: @download.errors.full_messages.to_sentence }
      end
    end
  end

  # DELETE /downloads/:id  (history only; the file stays)
  def destroy
    @download.cancel! if @download.can_cancel?
    @download.destroy
    redirect_to downloads_path, notice: "Download record deleted."
  end

  # DELETE /downloads/:id/destroy_file  (file + folder + record)
  def destroy_file
    @download.delete_files!
    @download.destroy
    redirect_to downloads_path, notice: "File and record permanently deleted."
  rescue StandardError => e
    redirect_to downloads_path, alert: "Could not delete the file: #{e.message}"
  end

  # POST /downloads/:id/pause
  def pause
    if @download.pause!
      redirect_to downloads_path, notice: "Download paused."
    else
      redirect_to downloads_path, alert: "Cannot pause this download. #{@download.errors.full_messages.to_sentence}".strip
    end
  end

  # POST /downloads/:id/resume
  def resume
    if @download.resume!
      redirect_to downloads_path, notice: "Download resumed."
    else
      redirect_to downloads_path, alert: "Cannot resume this download. #{@download.error_message}".strip
    end
  end

  # POST /downloads/:id/cancel
  def cancel
    if @download.cancel!
      redirect_to downloads_path, notice: "Download cancelled."
    else
      redirect_to downloads_path, alert: "Cannot cancel this download."
    end
  end

  private

  def set_download
    @download = Download.find(params[:id])
  end

  def download_params
    params.require(:download).permit(:url, :filename, :destination_path, :kind, :season, :episode, :episode_count)
  end
end
