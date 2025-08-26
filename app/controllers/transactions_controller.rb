class TransactionsController < ApplicationController
  def index
    @transactions = Transaction.all
  end

  def new
    @transactions = Transaction.new
  end

  def create
    # raise
    @transactions = Transaction.new(transactions_params)
    @transactions.user = current_user
    if @transactions.save
      redirect_to transactions_path
    else
      render "new", status: :unprocessable_entity
    end
  end

  private

  def transactions_params
    params.require(:transaction).permit(:description, :amount, :category_id, :date)
  end
end
