class TransactionsController < ApplicationController
  def expenses_until_same_day_last_month
    start_date = Date.current.last_month.beginning_of_month
    end_date = [
      Date.current.last_month.end_of_month,
      Date.current.last_month.change(day: Date.current.day)
    ].min

    where("amount > 0").where(created_at: start_date..end_date).sum(:amount)
  end

  def expenses_until_same_day_this_month
    start_date = Date.current.beginning_of_month
    end_date = [
      Date.current.end_of_month,
      Date.current.change(day: Date.current.day)
    ].min

    where("amount > 0").where(created_at: start_date..end_date).sum(:amount)
  end

  def expenses_past_30_days
    start_date = Date.current - 30
    end_date = Date.current

    where("amount > 0").where(created_at: start_date..end_date).sum(:amount)
  end
end
