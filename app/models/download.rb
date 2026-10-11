class Download < ApplicationRecord
  STATUSES = %w[pending downloading paused completed failed cancelled].freeze
  BLOCKED_EXTENSIONS = %w[.torrent .metalink .meta4].freeze
  KINDS = %w[movie episode season].freeze # season = a whole season in one file

  belongs_to :title, optional: true

  # Validations
  validates :url, presence: true, format: { with: URI::DEFAULT_PARSER.make_regexp(%w[http https]),
                                            message: "must be an http:// or https:// link" }
  validates :destination_path, presence: true
  validates :destination_path, inclusion: { in: ->(_) { Destinations.paths }, message: "is not an allowed destination" },
                               on: :create
  validates :filename, presence: true
  validates :status, inclusion: { in: STATUSES }
  validate :not_a_torrent, on: :create
  validates :kind, inclusion: { in: KINDS }
  validates :season, numericality: { only_integer: true, in: 0..99 }, if: :tv?
  validates :episode, numericality: { only_integer: true, in: 1..999 }, if: -> { kind == "episode" }
  validates :episode_count, numericality: { only_integer: true, in: 1..999 }, allow_nil: true

  before_validation :normalize_kind, on: :create

  # Scopes
  scope :recent, -> { order(created_at: :desc) }
  scope :active, -> { where(status: %w[pending downloading paused]) }
  scope :completed, -> { where(status: "completed") }
  scope :failed, -> { where(status: "failed") }

  # Turns user input into a safe single folder/file name, keeping spaces so
  # Jellyfin can match it: "Dangal (2016)" stays as is, "../etc" -> "etc".
  def self.sanitize_name(name)
    cleaned = name.to_s.gsub(/[[:cntrl:]\\\/:*?"<>|]/, " ").squeeze(" ").strip.sub(/\A[.\s]+/, "").sub(/[.\s]+\z/, "")
    cleaned.presence || "download"
  end

  # Status helpers
  STATUSES.each do |s|
    define_method(:"#{s}?") { status == s }
  end

  def can_pause?
    pending? || downloading?
  end

  def can_resume?
    paused? || failed?
  end

  def can_cancel?
    pending? || downloading? || paused?
  end

  # Actions (the engine does the real work)
  def start!
    DownloadEngine.current.start(self)
  end

  def pause!
    can_pause? && DownloadEngine.current.pause(self)
  end

  def resume!
    can_resume? && DownloadEngine.current.resume(self)
  end

  def cancel!
    can_cancel? && DownloadEngine.current.cancel(self)
  end

  def delete_files!
    DownloadEngine.current.delete_files(self)
  end

  # Paths (Jellyfin layout):
  #   movie:   <destination>/Dangal (2016)/Dangal (2016).mkv
  #   episode: <destination>/Panchayat (2020)/Season 03/Panchayat (2020) S03E02.mkv
  #   season:  <destination>/Panchayat (2020)/Season 03/Panchayat (2020) S03E01-E08.mkv
  def tv?
    kind.in?(%w[episode season])
  end

  def folder_name
    self.class.sanitize_name(filename)
  end

  def folder_path
    base = File.join(destination_path.chomp("/"), folder_name)
    tv? ? File.join(base, format("Season %02d", season.to_i)) : base
  end

  # "S03E02", "S03E01-E08" or "S03E01" (whole season, episode count unknown)
  def episode_code
    return unless tv?

    code = format("S%02dE%02d", season.to_i, kind == "episode" ? episode.to_i : 1)
    kind == "season" && episode_count.to_i > 1 ? "#{code}-E#{format('%02d', episode_count)}" : code
  end

  def file_name_with(extension)
    base = tv? ? "#{folder_name} #{episode_code}" : folder_name
    extension.present? && !base.end_with?(extension) ? "#{base}#{extension}" : base
  end

  def folder_inside_destination?
    base = File.expand_path(destination_path)
    target = File.expand_path(folder_path)
    target.start_with?("#{base}/") && target != base
  end

  # Display helpers
  def formatted_file_size
    file_size.nil? ? "Unknown" : self.class.human_bytes(file_size)
  end

  def formatted_speed
    download_speed.to_i.positive? ? "#{self.class.human_bytes(download_speed)}/s" : nil
  end

  def eta_seconds
    return nil unless downloading? && download_speed.to_i.positive? && file_size.to_i.positive?

    remaining = file_size * (1 - progress.to_f / 100)
    (remaining / download_speed).ceil
  end

  def formatted_eta
    secs = eta_seconds
    return nil unless secs

    h, rem = secs.divmod(3600)
    m, s = rem.divmod(60)
    if h.positive? then format("%dh %02dm", h, m)
    elsif m.positive? then format("%dm %02ds", m, s)
    else "#{s}s"
    end
  end

  def progress_percentage
    progress.to_f.round(0)
  end

  def as_status_json
    {
      id: id,
      status: status,
      progress: progress_percentage,
      speed: formatted_speed,
      eta: formatted_eta,
      size: formatted_file_size
    }
  end

  def self.human_bytes(bytes)
    units = %w[B KB MB GB TB]
    size = bytes.to_f
    unit = 0
    while size >= 1024 && unit < units.length - 1
      size /= 1024.0
      unit += 1
    end
    value = size.round(unit.zero? ? 0 : 1)
    "#{value == value.to_i ? value.to_i : value} #{units[unit]}"
  end

  private

  # Only TV destinations use episode/season; everything else is a movie-style folder.
  def normalize_kind
    self.kind = "movie" unless Destinations.tv?(destination_path) && kind.in?(%w[episode season])
    return if tv?

    self.season = self.episode = self.episode_count = nil
  end

  def not_a_torrent
    path = (URI.parse(url.to_s).path.to_s.downcase rescue "")
    return unless BLOCKED_EXTENSIONS.any? { |ext| path.end_with?(ext) }

    errors.add(:url, "is a torrent/metalink file; only direct HTTP/HTTPS file links are supported")
  end
end
