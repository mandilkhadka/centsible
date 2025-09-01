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
    #FFF2EB
    #E5BEB5
    #819A91
    #F2E2B1
    #E4E0E1
    #F8EDE3
    #627BEF
    #67BC76
    #A7B49E
  ]
  belongs_to :user

  validates :title, presence: true
  validates :limit, numericality: { only_integer: true }, allow_nil: true

  before_validation :capitalize_title

  private

  def capitalize_title
    return if title.blank?
    self.title = title.strip.capitalize
  end
end
