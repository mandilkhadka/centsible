class TransactionsController < ApplicationController
  include RangeFilterable

  def index
    set_range_and_totals

    @transactions_income = @filtered_transactions
                            .incomes
                            .includes(:category)
                            .order(date: :desc, id: :desc)

    @transactions_expense = @filtered_transactions
                              .expenses
                              .includes(:category)
                              .order(date: :desc, id: :desc)
  end

  def create
    @transaction = Transaction.new(transactions_params)
    @transaction.user = current_user
    @category_totals = current_user.transactions.joins(:category).group("categories.title").sum(:amount)
    if @transaction.transaction_type == "income"
      income_category = Category.find_or_create_by!(title: "Income", user: current_user)
      @transaction.category = income_category
    end

    if @transaction.save
      if @transaction.transaction_type == "expense"

        budget = @transaction.category.limit

        spent = @category_totals[@transaction.category.title] || 0
          if spent + @transaction.amount >= budget
            flash[:alert] = "You have reached your monthly budget limit for #{@transaction.category.title}."
          end

      end

      redirect_to transactions_path
    else
      @transactions = current_user.transactions.order(created_at: :desc)
      @categories   = current_user.categories
      flash[:alert] = "Failed to add. Please fill all the input fields and put in the positive value."
      render "users/dashboard", status: :unprocessable_entity
    end
  end

  private

  def transactions_params
    params.require(:transaction).permit(:description, :amount, :category_id, :date, :transaction_type)
  end
end
