class Category < ApplicationRecord
  COLORS = %w[
    red
    green
    yellow
    blue
    brown
    pink
    grey
  ]
  belongs_to :user

  validates :title, presence: true
  validates :limit, numericality: { only_integer: true }, allow_nil: true
end
