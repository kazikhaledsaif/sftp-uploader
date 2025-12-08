require 'net/sftp'
require 'tempfile'

class DownloadJob < ApplicationJob
  queue_as :default

  require 'net/sftp'
  require 'uri'
  require 'httparty'

  def perform(download_id)
    @download = Download.find(download_id)
    
    begin
      @download.update(status: 'downloading', progress: 0)
      
      # Stream directly from URL to SFTP
      stream_download_to_sftp
      
      @download.update(status: 'completed', progress: 100)
    rescue => e
      Rails.logger.error "Download failed for #{@download.id}: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      @download.update(status: 'failed', error_message: e.message)
    end
  end

  private

  def stream_download_to_sftp
    sftp_config = load_sftp_config
    
    Net::SFTP.start(
      sftp_config['host'],
      sftp_config['username'],
      password: sftp_config['password'],
      port: sftp_config['port'] || 22,
      timeout: sftp_config['timeout'] || 60,
      non_interactive: true,
      auth_methods: ['password']
    ) do |sftp|
      # Get file details from HEAD request first
      response = HTTParty.head(@download.url, follow_redirects: true)
      total_size = response.headers['content-length']&.to_i
      content_type = response.headers['content-type']
      content_disposition = response.headers['content-disposition']
      
      @download.update(file_size: total_size) if total_size
      
      # Build upload path using headers if needed
      upload_path = build_upload_path(content_disposition, content_type)
      ensure_remote_directory(sftp, File.dirname(upload_path))
      
      # Create a pipe for streaming
      # reader -> passed to SFTP upload
      # writer -> written to by HTTP download
      reader, writer = IO.pipe
      
      # Monkey-patch reader to look like a file with size (needed for SFTP progress)
      if total_size
        reader.define_singleton_method(:size) { total_size }
        reader.define_singleton_method(:stat) { OpenStruct.new(size: total_size) }
      end

      # Start Download in a separate thread
      download_thread = Thread.new do
        begin
          HTTParty.get(@download.url, stream_body: true, follow_redirects: true) do |fragment|
            # Write chunk to pipe (blocks if pipe is full, providing backpressure)
            writer.write(fragment)
          end
        rescue => e
          Rails.logger.error "HTTP Download error: #{e.message}"
          # Close writer with error to signal reader
          writer.close
          raise e
        ensure
          writer.close
        end
      end
      
      # Start Upload in main thread (reads from pipe)
      begin
        last_progress_update = Time.current
        uploaded_bytes = 0
        
        # Open remote file for writing using the File wrapper
        sftp.file.open(upload_path, 'w') do |f|
          # Read from pipe and write to SFTP
          while chunk = reader.read(65536) # Read 64KB chunks
            # Write chunk to remote file (offset managed automatically)
            f.write(chunk)
            
            uploaded_bytes += chunk.length
            
            # Throttle DB updates (every 1 second)
            if total_size && total_size > 0 && (Time.current - last_progress_update > 1.second)
              progress = (uploaded_bytes.to_f / total_size * 100).round(2)
              @download.update(progress: progress)
              last_progress_update = Time.current
            end
          end
        end
        
        Rails.logger.info "Upload completed for #{@download.id} to #{upload_path}"
        
        # Wait for download thread to finish cleanly
        download_thread.join
      ensure
        reader.close
        # Ensure thread is killed if we exit early
        download_thread.kill if download_thread.alive?
      end
    end
  end

  def get_content_length
    # Deprecated, logic moved to stream_download_to_sftp
  end

  def build_upload_path(content_disposition = nil, content_type = nil)
    base_path = @download.destination_path.chomp('/')
    
    # Extract extension
    extension = extract_extension(content_disposition, content_type)
    
    # Use the provided filename as both the folder name and the file name
    folder_name = sanitize_folder_name(@download.filename)
    
    # Ensure extension is present
    new_filename = folder_name
    new_filename += extension if extension.present? && !new_filename.end_with?(extension)
    
    "#{base_path}/#{folder_name}/#{new_filename}"
  end

  def extract_extension(content_disposition, content_type)
    # 1. Try from URL
    url_path = URI.parse(@download.url).path
    ext = File.extname(url_path)
    return ext if ext.present?
    
    # 2. Try from Content-Disposition
    if content_disposition.present?
      filename = content_disposition[/filename="?([^"]+)"?/, 1]
      if filename
        ext = File.extname(filename)
        return ext if ext.present?
      end
    end
    
    # 3. Try from Content-Type
    if content_type.present?
      require 'mime/types'
      type = MIME::Types[content_type].first
      return ".#{type.extensions.first}" if type && type.extensions.any?
    end
    
    ''
  end

  def sanitize_folder_name(name)
    # Replace invalid characters with underscore
    name.gsub(%r{[\\/:*?"<>|]}, '_')
  end

  def ensure_remote_directory(sftp, path)
    return if path == '.' || path == '/'
    
    begin
      sftp.stat!(path)
    rescue Net::SFTP::StatusException
      # Directory doesn't exist, try creating parent first
      ensure_remote_directory(sftp, File.dirname(path))
      begin
        sftp.mkdir!(path)
      rescue Net::SFTP::StatusException => e
        # Ignore if it was created concurrently
        raise e unless e.code == 4 # failure
      end
    end
  end

  def load_sftp_config
    config_file = Rails.root.join('config', 'sftp_config.yml')
    
    if File.exist?(config_file)
      # Process ERB in the YAML file
      yaml_content = ERB.new(File.read(config_file)).result
      config = YAML.safe_load(yaml_content, permitted_classes: [], permitted_symbols: [], aliases: true)
      return config[Rails.env] || config['default'] if config.present?
    end
    
    # Fallback to environment variables
    {
      'host' => ENV['SFTP_HOST'] || 'localhost',
      'username' => ENV['SFTP_USERNAME'] || 'user',
      'password' => ENV['SFTP_PASSWORD'] || 'password',
      'port' => ENV['SFTP_PORT']&.to_i || 22,
      'timeout' => ENV['SFTP_TIMEOUT']&.to_i || 30
    }
  end

  def ensure_remote_directory(sftp, path)
    return if path == '/' || path == '.'
    
    begin
      sftp.stat!(path)
    rescue Net::SFTP::StatusException
      # Directory doesn't exist, create it
      ensure_remote_directory(sftp, File.dirname(path))
      sftp.mkdir!(path)
    end
  end
end
