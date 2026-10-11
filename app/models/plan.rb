# A title (or one TV season) planned for a date.
class Plan < ApplicationRecord
  belongs_to :title

  validates :planned_on, presence: true

  scope :upcoming, -> { where(planned_on: Date.current..).order(:planned_on) }
  scope :overdue, -> { where(planned_on: ...Date.current).order(:planned_on) }

  def label
    season_number ? "#{title.name}, Season #{season_number}" : title.name
  end
end
