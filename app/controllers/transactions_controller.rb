class TransactionsController < ApplicationController
  def compare_last_month
    this_month = Transaction.total_expenses_from_start_of_month
    last_month = Transaction.total_expenses_until_same_day_last_month
    spending_difference = (this_month - last_month) / last_month.to_f
    spending_difference.round(2)
  end

  def daily_average
    Transaction.total_expenses_past_30_days / 30
  end
end
