# app/models/transaction.rb
class Transaction < ApplicationRecord
  belongs_to :user
  belongs_to :category

  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :description, presence: true

  # Existing date scopes (yours)
  scope :this_month,     -> { where(date: Time.zone.today.beginning_of_month..Time.zone.today.end_of_month) }
  scope :last_month,     -> {
    start  = Time.zone.today.last_month.beginning_of_month
    finish = Time.zone.today.last_month.end_of_month
    where(date: start..finish)
  }
  scope :last_6_months,  -> { where(date: 5.months.ago.beginning_of_month..Time.zone.today.end_of_month) }
  scope :all_time,       -> { all }

  # Type scopes (nice to have)
  scope :incomes,  -> { where(transaction_type: "income") }
  scope :expenses, -> { where(transaction_type: "expense") }

  # ---------- user-scoped helpers ----------
  def self.total_expenses_from_start_of_month_for(user)
    user.transactions.expenses.where(date: Date.current.beginning_of_month..Date.current).sum(:amount)
  end

  def self.total_expenses_until_same_day_last_month_for(user)
    user.transactions.expenses.where(date: Date.current.last_month.beginning_of_month..Date.current.last_month).sum(:amount)
  end

  def self.total_expenses_past_30_days_for(user)
    user.transactions.expenses.where(date: (Date.current - 30)..Date.current).sum(:amount)
  end
end
