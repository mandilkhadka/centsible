class TransactionsController < ApplicationController
  def index
    @transactions = Transaction.all
    # Sorting it out in html file
    @transactions = Transaction.order(date: :desc)
    @total_income = current_user.total_income
    @total_spent = current_user.total_spent
    @available_balance = current_user.available_balance
  end

  def create
    @transaction = Transaction.new(transactions_params)
    @transaction.user = current_user
    # budget
    @category_totals = current_user.transactions.joins(:category).group("categories.title").sum(:amount)
    # budget
    #
    # Filtering if it is income or expense
    if @transaction.transaction_type == "income"
      income_category = Category.find_or_create_by(title: "Income", user: current_user)
      @transaction.category = income_category
    end
    # Transaction saving
    if @transaction.save
      # Budget
      if @category_totals[@transaction.category.title] >= @transaction.category.limit
        flash[:alert] = "You have reached your monthly budget limit for #{@transaction.category.title}."
      end
      redirect_to transactions_path
    else
      @transactions = current_user.transactions.order(created_at: :desc)
      @categories   = current_user.categories
      # Have to close it manually; to automatically remove the alert; we have to use stimulus JS
      flash[:alert] = 'Failed to add. Please fill all the input fields and put in the positive value.'
      render "users/dashboard", status: :unprocessable_entity
    end
  end

  private

  def transactions_params
    params.require(:transaction).permit(:description, :amount, :category_id, :date, :transaction_type)
  end
end
