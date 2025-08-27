class TransactionsController < ApplicationController
  def index
    @transactions = Transaction.all

    # If we wan to sort it out in html file we need this line
    # @transactions = current_user.transactions.order(created_at: :desc)
    # @income =
    @total_spent = current_user.transactions.sum(:amount)
    @available_balance = current_user.starting_balance - @total_spent 
    # @income = current_user.starting_balance
  end

  # def new
  #   @transactions = Transaction.new
  # end

  def create
    # if transaction_type == "expense"
    @transaction = Transaction.new(transactions_params)
    @transaction.user = current_user

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
    params.require(:transaction).permit(:description, :amount, :category_id, :date)
  end
end
