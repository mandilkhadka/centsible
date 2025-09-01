class CategoriesController < ApplicationController
  def index
    @category = Category.new

    base = current_user.transactions
    @range = params[:range].presence || "this_month"

    filtered = case @range
            when "this_month"    then base.this_month
            when "last_month"    then base.last_month
            when "last_6_months" then base.last_6_months
            when "total"         then base.all_time
            else                     base.this_month
            end

    @transactions    = filtered.includes(:category).group_by(&:category)
    @category_totals = filtered.joins(:category).group("categories.title").sum(:amount)
  end

  def create
    @category = Category.new(category_params)
    @category_totals = current_user.transactions.joins(:category).group("categories.title").sum(:amount)
    @category.user = current_user
    if @category.save
      redirect_to root_path
    else
      @transactions = current_user.transactions.group_by(&:category)
      render "index", status: :unprocessable_entity
    end
  end

  def budget
    @categories = Category.all
  end

  private

  def category_params
    params.require(:category).permit(:title, :limit)
  end
end
