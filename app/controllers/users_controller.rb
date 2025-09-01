class UsersController < ApplicationController
  include RangeFilterable
  def dashboard
    set_range_and_totals
    @transaction = Transaction.new
    @transactions = current_user.transactions.order(created_at: :desc)
    @categories  = current_user.categories
    @user_message = Message.new

    this_month = Transaction.total_expenses_from_start_of_month_for(current_user)
    same_day_last_month = Transaction.total_expenses_until_same_day_last_month_for(current_user)

    @percentage_compare =
      if same_day_last_month.zero?
        nil
      else
        ((this_month - same_day_last_month) / same_day_last_month.to_f) * 100.0
      end

    @daily_average_30d = Transaction.total_expenses_past_30_days_for(current_user) / 30.0
  end
end
