class PastExpenseTool < RubyLLM::Tool
  def initialize(user)
    @user = user
  end

  def execute
    transactions = @user.transactions
    JSON.parse(transactions.select(:description, :amount, :date).to_json)
  end

end
