class Saving < ApplicationRecord
  belongs_to :user
  has_many :transactions
  validates :title, presence: true
  validates :goal, presence: true, numericality: { greater_than: 0 }

  # How much has been deposited into this saving (sum of expense transactions linked to it)
  def amount_saved
    transactions.where(transaction_type: "expense").sum(:amount)
  end

  def progress_pct
    return 0 if goal.to_i <= 0
    ((amount_saved.to_f / goal.to_f) * 100).round
  end
end

