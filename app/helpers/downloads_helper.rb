module DownloadsHelper
  def status_badge_class(status)
    case status
    when 'pending'
      'badge-warning'
    when 'downloading'
      'badge-info'
    when 'paused'
      'badge-secondary'
    when 'completed'
      'badge-success'
    when 'failed'
      'badge-danger'
    when 'cancelled'
      'badge-dark'
    else
      'badge-light'
    end
  end

  def format_file_size(bytes)
    return 'Unknown' if bytes.nil?
    
    units = ['B', 'KB', 'MB', 'GB', 'TB']
    size = bytes.to_f
    unit_index = 0
    
    while size >= 1024 && unit_index < units.length - 1
      size /= 1024.0
      unit_index += 1
    end
    
    "#{size.round(2)} #{units[unit_index]}"
  end
end
