# App-wide settings that survive restarts.
#   Setting["speed_mode"]          # => "balanced" or nil
#   Setting["speed_mode"] = "full"
class Setting < ApplicationRecord
  validates :key, presence: true, uniqueness: true

  def self.[](key)
    find_by(key: key.to_s)&.value
  end

  def self.[]=(key, value)
    record = find_or_initialize_by(key: key.to_s)
    record.update!(value: value.to_s)
  end
end
