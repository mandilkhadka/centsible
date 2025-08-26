class UsersController < ApplicationController
  def compare_last_month
    this_month = Transaction.expenses_until_same_day_this_month
    last_month = Transaction.expenses_until_same_day_last_month
    spending_difference = (this_month - last_month) / last_month.to_f
    number_to_percentage.call(spending_difference)
  end

  def daily_average
    Transaction.expenses_past_30_days / 30
  end
end
