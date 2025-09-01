class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable, :recoverable, :rememberable, :validatable

  has_many :categories
  has_many :messages
  has_many :transactions
  has_many :savings

  # validates :name, presence: true
  # validates :starting_balance, numericality: { only_integer: true }

  def total_income
    transactions.where(transaction_type: "income").sum(:amount)
  end

  def total_spent
    transactions.where(transaction_type: "expense").sum(:amount)
    # Transaction.where(date: (Date.current.beginning_of_month)..Date.current).sum(:amount).where(transaction_type: "expense").sum(:amount)
  end

  def available_balance
    starting_balance + total_income - total_spent
  end
end
