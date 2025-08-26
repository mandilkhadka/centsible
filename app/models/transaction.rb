class Transaction < ApplicationRecord
  belongs_to :user
  belongs_to :category

  validates :amount, presence: true
  validates :description, presence: true

  def self.total_expenses_from_start_of_month
    Transaction.where("amount > 0").where(date: (Date.current.beginning_of_month)..Date.current).sum(:amount)
  end

  def self.total_expenses_until_same_day_last_month
    Transaction.where("amount > 0").where(date: (Date.current.last_month.beginning_of_month)..Date.current.last_month).sum(:amount)
  end

  def self.total_expenses_past_30_days
    Transaction.where("amount > 0").where(date: (Date.current - 30)..Date.current).sum(:amount)
  end
end
