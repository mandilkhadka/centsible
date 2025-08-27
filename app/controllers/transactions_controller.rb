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
    # if transaction_type == "expense"
    @transaction = Transaction.new(transactions_params)
    @transaction.user = current_user

    if @transaction.transaction_type == "income"
      income_category = Category.find_or_create_by(title: "Income", user: current_user)
      @transaction.category = income_category
    end
    if @transaction.save
      redirect_to transactions_path
    else
      @transactions = current_user.transactions.order(created_at: :desc)
      @categories   = current_user.categories
      render "users/dashboard", status: :unprocessable_entity
    end
  end

  private

  def transactions_params
    params.require(:transaction).permit(:description, :amount, :category_id, :date, :transaction_type)
  end
end
