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
    transactions.where("LOWER(transaction_type) LIKE ?", "%income%").sum(:amount)
  end

  def total_spent
    transactions.where("LOWER(transaction_type) LIKE ?", "%expense%").sum(:amount)
  end

  def available_balance
    starting_balance + total_income - total_spent
  end
end
