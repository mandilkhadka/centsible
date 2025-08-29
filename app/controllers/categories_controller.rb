class CategoriesController < ApplicationController
  def index
    @category = Category.new
    @transactions = current_user.transactions.group_by(&:category)
    @category_totals = current_user.transactions.joins(:category).group("categories.title").sum(:amount)

    # @categories = current_user.categories.includes(@transaction)
    # raise
  end
  def create
    @category = Category.new(category_params)
    if @category.save
      redirect_to categories_path
    else
      @transactions = current_user.transactions.group_by(&:category)
      render "index", status: :unprocessable_entity
    end
  end

  private
  #   def tansactions_budget
  # @category.user = current_user
  # @transactions = current_user.transactions.group_by(&:category)
  # if @transactions >= @category.user.limit
  #   flash[:alert] = 'You have reached your monthly budget limit.'
  # end
  # end

  def category_params
    params.require(:category).permit(:title, :limit)
  end
end
