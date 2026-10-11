class TitleSeason < ApplicationRecord
  belongs_to :title

  validates :number, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :status, inclusion: { in: %w[want watched] }

  def watched?
    status == "watched"
  end

  def label
    number.zero? ? "Specials" : "Season #{number}"
  end
end
