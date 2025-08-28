class CategoriesController < ApplicationController
  def index
    @category = Category.new
    @transactions = current_user.transactions.group_by(&:category)
    @category_totals = current_user.transactions.joins(:category).group("categories.title").sum(:amount)
  end
  def create
    @category = Category.new(category_params)
    @category.user = current_user
    if @category.save
      redirect_to categories_path
    else
      @transactions = current_user.transactions.group_by(&:category)
      render "index", status: :unprocessable_entity
    end
  end

  private

  def category_params
    params.require(:category).permit(:title, :limit)
  end


end
