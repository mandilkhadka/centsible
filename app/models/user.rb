class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
      :recoverable, :rememberable, :validatable

  has_many :categories
  has_many :messages
  has_many :transactions

    # validates :name, presence: true
    # validates :starting_balance, numericality: { only_integer: true }
end
