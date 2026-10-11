require "open3"

# Free and total space of the disk a folder lives on (via `df`).
#   DiskSpace.for("/data/Movies") # => { free: 1.2e12, total: 4.0e12 } or nil
module DiskSpace
  CACHE_FOR = 30.seconds

  module_function

  def for(path)
    Rails.cache.fetch("disk_space/#{path}", expires_in: CACHE_FOR) { measure(path) }
  end

  # Below 10% free, or less than 20 GB: worth a warning.
  def low?(space)
    space && (space[:free] < 20 * 1024**3 || space[:free] < space[:total] * 0.10)
  end

  def measure(path)
    dir = existing_parent(path)
    out, status = Open3.capture2("df", "-Pk", dir)
    return unless status.success?

    # Filesystem 1024-blocks Used Available Capacity Mounted-on
    cols = out.lines.last.to_s.split
    total, available = cols[1].to_i * 1024, cols[3].to_i * 1024
    total.positive? ? { free: available, total: total } : nil
  rescue SystemCallError => e
    Rails.logger.warn("Disk space check for #{path} failed: #{e.message}")
    nil
  end

  # A destination folder may not exist yet (it is created on the first download).
  def existing_parent(path)
    dir = File.expand_path(path.to_s)
    dir = File.dirname(dir) until File.directory?(dir) || dir == "/"
    dir
  end
end
