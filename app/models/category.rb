class Category < ApplicationRecord
  belongs_to :user

  validates :title, presence: true
  validates :limit, numericality: { only_integer: true }
end
