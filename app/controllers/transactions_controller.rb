class TransactionsController < ApplicationController
# app/controllers/transactions_controller.rb
  def index
    @range = params[:range].presence || "this_month"

    base = current_user.transactions.includes(:category)

    filtered = case @range
              when "this_month"    then base.this_month
              when "last_month"    then base.last_month
              when "last_6_months" then base.last_6_months
              when "total"         then base.all_time
              else                     base.this_month
              end

    @transactions_expense = filtered
                              .joins(:category)
                              .where.not(categories: { title: "Income" })
                              .order(date: :desc, id: :desc)

    @transactions_income  = filtered
                              .joins(:category)
                              .where(categories: { title: "Income" })
                              .order(date: :desc, id: :desc)

    # Header numbers (filtered):
    @total_income = @transactions_income.sum(:amount)
    @total_spent  = @transactions_expense.sum(:amount)
    @available_balance = current_user.starting_balance + @total_income - @total_spent
  end


  def create
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
