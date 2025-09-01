class CategoriesController < ApplicationController
  include RangeFilterable

  def index
    @category = Category.new

    set_range_and_totals

    # Use the already-filtered relation for groups & charts
    @transactions    = @filtered_transactions.includes(:category).group_by(&:category)
    @category_totals = @filtered_transactions.joins(:category).group("categories.title").sum(:amount)
  end

  def create
    @category = Category.new(category_params)
    @category.user = current_user
    if @category.save
      redirect_to root_path
    else
      # fallback (unfiltered) to re-render the page
      @transactions = current_user.transactions.group_by(&:category)
      render "index", status: :unprocessable_entity
    end
  end

  def budget
    @categories = Category.all
  end

  def saving
    @categories = current_user.categories
  end

  private

  def category_params
    params.require(:category).permit(:title, :limit)
  end
end
