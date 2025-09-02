class TextTransactionMakerTool < RubyLLM::Tool
  description "Drafts a transaction from user input without saving"
  param :description, desc: "Description of transaction provided by user (e.g., morning coffee)"
  param :amount, desc: "the monetary value"
  param :transaction_type, desc: "must be either expense or income"
  param :date, desc: "the transaction date"
  param :category, desc: "category of the transaction based on description"


  def initialize(user, categories_tool)
    @user = user
    @categories_tool = categories_tool
  end

  def execute(description:, amount:, transaction_type:, date:, category: nil)
    category = @categories_tool.execute(description)

    transaction = @user.transactions.new( description: description, amount: amount, category: category, transaction_type: transaction_type, date: date )

    transaction.save!
    transaction
  end
end
