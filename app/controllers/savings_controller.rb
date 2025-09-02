class SavingsController < ApplicationController
  def index
    @savings = current_user.savings.order(created_at: :desc)
    @saving  = Saving.new
  end

  def create
    @saving = current_user.savings.new(saving_params)
    if @saving.save
      redirect_to savings_path
    else
      @savings = current_user.savings.order(created_at: :desc)
      render "index", status: :unprocessable_entity
    end
  end

  # POST /savings/:id/deposits
  def deposits
    saving = current_user.savings.find(params[:id])

    # sanitize amount (accepts "10,000" or "10000")
    amount = params[:amount].to_s.gsub(/[^\d]/, "").to_i
    if amount <= 0
      redirect_to savings_path, alert: "Amount must be positive." and return
    end

    date = params[:date].present? ? Date.parse(params[:date]) : Date.current
    desc = params[:description].presence || "Saving deposit"

    # Ensure a 'Savings' category exists
    savings_category = current_user.categories.find_or_create_by!(title: "Savings")

    current_user.transactions.create!(
      description: desc,
      amount: amount,
      date: date,
      transaction_type: "expense", # deposit reduces available balance
      category: savings_category,
      saving: saving
    )

    formatted = helpers.number_to_currency(amount, unit: "¥", precision: 0, delimiter: ",")
    redirect_to savings_path, notice: "Deposited #{formatted} into #{saving.title}."
  rescue ArgumentError
    redirect_to savings_path, alert: "Invalid date."
  end


  private

  def saving_params
    params.require(:saving).permit(:title, :goal)
  end
end
