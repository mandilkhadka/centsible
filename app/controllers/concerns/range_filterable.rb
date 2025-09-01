# app/controllers/concerns/range_filterable.rb
# frozen_string_literal: true
module RangeFilterable
  extend ActiveSupport::Concern

  private

  def filtered_transactions_for(user, range_key)
    base = user.transactions
    case range_key
    when "this_month"    then base.this_month
    when "last_month"    then base.last_month
    when "last_6_months" then base.last_6_months
    when "total"         then base.all_time
    else                      base.this_month
    end
  end

  # Sets:
  # - @range
  # - @filtered_transactions
  # - @total_income, @total_spent  (respect the range filter)
  # - @available_balance           (IGNORES range; always "now")
  def set_range_and_totals
    @range = params[:range].presence || "this_month"
    @filtered_transactions = filtered_transactions_for(current_user, @range)

    # Filtered totals (for "Spent this month/last month/…")
    filtered_sums = @filtered_transactions.group(:transaction_type).sum(:amount)
    @total_income = filtered_sums["income"].to_i
    @total_spent  = filtered_sums["expense"].to_i

    # Unfiltered available balance = starting + all income to date - all expenses to date
    @available_balance = compute_available_balance(current_user)
  end

  # All-time (to today) available balance; ignores @range
  def compute_available_balance(user)
    sums = user.transactions.where("date <= ?", Date.current)
                            .group(:transaction_type).sum(:amount)
    income  = sums["income"].to_i
    expense = sums["expense"].to_i
    user.starting_balance + income - expense
  end
end
