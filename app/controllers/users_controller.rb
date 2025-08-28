class UsersController < ApplicationController

  def dashboard
    @transaction = Transaction.new
    @transactions = current_user.transactions.order(created_at: :desc)
    @categories  = current_user.categories
    @user_message = Message.new
  end
end
