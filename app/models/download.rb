class Download < ApplicationRecord
  # Validations
  validates :url, presence: true, format: { with: URI::DEFAULT_PARSER.make_regexp(%w[http https]) }
  validates :destination_path, presence: true
  validates :filename, presence: true # Now required
  validates :status, inclusion: { in: %w[pending downloading paused completed failed cancelled] }

  # Scopes
  scope :recent, -> { order(created_at: :desc) }
  scope :active, -> { where(status: %w[pending downloading paused]) }
  scope :completed, -> { where(status: 'completed') }
  scope :failed, -> { where(status: 'failed') }

  # Callbacks
  # No longer setting default filename as it's required input

  # Status helpers
  def pending?
    status == 'pending'
  end

  def downloading?
    status == 'downloading'
  end

  def paused?
    status == 'paused'
  end

  def completed?
    status == 'completed'
  end

  def failed?
    status == 'failed'
  end

  def cancelled?
    status == 'cancelled'
  end

  def can_pause?
    downloading?
  end

  def can_resume?
    paused?
  end

  def can_cancel?
    pending? || downloading? || paused?
  end

  # Actions
  def pause!
    update(status: 'paused') if can_pause?
  end

  def resume!
    if can_resume?
      update(status: 'pending')
      DownloadJob.perform_later(id)
    end
  end

  def cancel!
    update(status: 'cancelled') if can_cancel?
  end

  # Display helpers
  def formatted_file_size
    return 'Unknown' if file_size.nil?
    
    units = ['B', 'KB', 'MB', 'GB', 'TB']
    size = file_size.to_f
    unit_index = 0
    
    while size >= 1024 && unit_index < units.length - 1
      size /= 1024.0
      unit_index += 1
    end
    
    "#{size.round(2)} #{units[unit_index]}"
  end

  def progress_percentage
    progress.round(0)
  end


  private

end
