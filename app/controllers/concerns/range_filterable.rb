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

  # Sets @range, @filtered_transactions, @total_income, @total_spent, @available_balance
  def set_range_and_totals
    @range = params[:range].presence || "this_month"
    @filtered_transactions = filtered_transactions_for(current_user, @range)

    # 1 SQL round-trip; keys like {"income"=>12345, "expense"=>6789}
    sums = @filtered_transactions.group(:transaction_type).sum(:amount)
    @total_income = sums["income"].to_i
    @total_spent  = sums["expense"].to_i
    @available_balance = current_user.starting_balance + @total_income - @total_spent
  end
end
