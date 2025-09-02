class PastTransactionTool < RubyLLM::Tool
  description "Gets past transaction data"

  def initialize(user)
    @user = user
  end

  def execute
    transactions = @user.transactions
    transactions.select(:description, :amount, :date, :transaction_type, :category_id).as_json
  end
end
