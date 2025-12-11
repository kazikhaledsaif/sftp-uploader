require 'net/sftp'

class DownloadsController < ApplicationController
  before_action :set_download, only: [:show, :edit, :update, :destroy, :pause, :resume, :cancel, :destroy_file]

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
    redirect_to downloads_url, notice: 'Download record deleted.'
  end

  # DELETE /downloads/:id/destroy_file
  def destroy_file
    # Only attempt SFTP deletion if we have a filename and path
    if @download.filename.present? && @download.destination_path.present?
      config = YAML.load_file(Rails.root.join('config', 'sftp_config.yml'))[Rails.env]
      
      begin
        Net::SFTP.start(config['host'], config['username'], password: config['password'], port: config['port'] || 22, timeout: config['timeout'] || 30) do |sftp|
          remote_path = File.join(@download.destination_path, @download.filename)
          
          begin
            # Try to stat the file to see if it exists
            sftp.stat!(remote_path)
            
            # If we get here, file exists. Delete it.
            sftp.remove!(remote_path)
            
            # Try to remove the directory (optional)
            begin
              sftp.rmdir!(@download.destination_path)
            rescue Net::SFTP::StatusException
              # Directory likely not empty or in use, ignore
            end
            
            # If successful, destroy record
            @download.destroy
            redirect_to downloads_url, notice: 'File and record permanently deleted.'
            
          rescue Net::SFTP::StatusException => e
            # File not found or other SFTP error
            if e.code == 2 # SSH_FX_NO_SUCH_FILE
              redirect_to downloads_url, alert: 'Error: File not found on server.'
            else
              redirect_to downloads_url, alert: "SFTP Error: #{e.message}"
            end
          end
        end
      rescue StandardError => e
        redirect_to downloads_url, alert: "Connection Error: #{e.message}"
      end
    else
      redirect_to downloads_url, alert: 'Cannot delete file: Filename or path missing.'
    end
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
