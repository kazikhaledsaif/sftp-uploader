class DownloadsController < ApplicationController
  before_action :set_download, only: [:show, :edit, :update, :destroy, :pause, :resume, :cancel]

  # GET /downloads
  def index
    @downloads = Download.recent
    @active_downloads = Download.active.count
    @completed_downloads = Download.completed.count
  end

  # GET /downloads/:id
  def show
  end

  # GET /downloads/new
  def new
    @download = Download.new
  end

  # GET /downloads/:id/edit
  def edit
  end

  # POST /downloads
  def create
    @download = Download.new(download_params)
    @download.status = 'pending'

    if @download.save
      # Enqueue the download job
      DownloadJob.perform_later(@download.id)
      
      redirect_to downloads_path, notice: 'Download started successfully.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /downloads/:id
  def update
    if @download.update(download_params)
      redirect_to @download, notice: 'Download was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /downloads/:id
  def destroy
    @download.destroy
    redirect_to downloads_url, notice: 'Download was successfully deleted.'
  end

  # POST /downloads/:id/pause
  def pause
    if @download.pause!
      redirect_to downloads_path, notice: 'Download paused.'
    else
      redirect_to downloads_path, alert: 'Cannot pause this download.'
    end
  end

  # POST /downloads/:id/resume
  def resume
    if @download.resume!
      redirect_to downloads_path, notice: 'Download resumed.'
    else
      redirect_to downloads_path, alert: 'Cannot resume this download.'
    end
  end

  # POST /downloads/:id/cancel
  def cancel
    if @download.cancel!
      redirect_to downloads_path, notice: 'Download cancelled.'
    else
      redirect_to downloads_path, alert: 'Cannot cancel this download.'
    end
  end

  private

  def set_download
    @download = Download.find(params[:id])
  end

  def download_params
    params.require(:download).permit(:url, :filename, :destination_path)
  end
end
