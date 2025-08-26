class UsersController < ApplicationController
  def compare_last_month
    number_to_percentage.call((Transcation.expenses_until_same_day_last_month - Transaction.this_month_expenses) / Transcation.expenses_until_same_day_last_month)
  end
end
