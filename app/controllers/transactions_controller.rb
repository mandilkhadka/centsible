class TransactionsController < ApplicationController
  def expenses_until_same_day_last_month
    start_date = Time.current.last_month.beginning_of_month

    end_date = [
      Time.current.last_month.end_of_month,
      Time.current.last_month.change(day: Time.current.day)
    ].min

    where("amount > 0").where(created_at: start_date..end_date)
  end

  def expenses_until_same_day_this_month
    start_date = Time.current.beginning_of_month

    end_date = [
    Time.current.end_of_month,
    Time.current.change(day: Time.current.day)
    ].min

    where("amount > 0").where(created_at: start_date..end_date)
  end
end
