class Transaction < ApplicationRecord
  belongs_to :user
  belongs_to :category

  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :description, presence: true

  # Scopes so we can sort out the categories and transactions indexes
  scope :this_month,     -> { where(date: Time.zone.today.beginning_of_month..Time.zone.today.end_of_month) }
  scope :last_month,     -> {
    start = Time.zone.today.last_month.beginning_of_month
    finish = Time.zone.today.last_month.end_of_month
    where(date: start..finish)
  }
  scope :last_6_months,  -> { where(date: 5.months.ago.beginning_of_month..Time.zone.today.end_of_month) }
  scope :all_time,       -> { all }


  def self.total_expenses_from_start_of_month
    Transaction.where(transaction_type: "expense").where(date: (Date.current.beginning_of_month)..Date.current).sum(:amount)
  end

  def self.total_expenses_until_same_day_last_month
    Transaction.where(transaction_type: "expense").where(date: (Date.current.last_month.beginning_of_month)..Date.current.last_month).sum(:amount)
  end

  def self.total_expenses_past_30_days
    Transaction.where(transaction_type: "expense").where(date: (Date.current - 30)..Date.current).sum(:amount)
  end

  def self.percentage_compared_to_last_month
    this_month = Transaction.total_expenses_from_start_of_month
    last_month = Transaction.total_expenses_until_same_day_last_month
    (this_month - last_month) / last_month.to_f
  end

  def self.daily_average
    Transaction.total_expenses_past_30_days / 30
  end
end
