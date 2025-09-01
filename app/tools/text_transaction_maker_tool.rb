class TextTransactionMakerTool < RubyLLM::Tool
  description "Drafts a transaction from user input without saving"

  def initialize(user, categories_tool)
    @user = user
    @categories_tool = categories_tool
  end

  def execute(details)
    details = details.transform_keys(&:to_sym)

    if details[:category].nil? || details[:category].is_a?(String)
      details[:category] = @categories_tool.execute(description: details[:description])
    end

    transaction = @user.transactions.new(details)
    transaction.save!
  end
end
