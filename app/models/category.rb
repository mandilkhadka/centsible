class Category < ApplicationRecord
  COLORS = %w[
    #d0b1fc
    #F7C5DD
    #DBD2E0
    #FAEDC7
    #8399A6
    #CAEEBE
    #FDFD95
    #E3E9BE
    #98E2F7
    #627BEF
    #67BC76
  ]
  belongs_to :user

  validates :title, presence: true
  validates :limit, numericality: { only_integer: true }, allow_nil: true
end
