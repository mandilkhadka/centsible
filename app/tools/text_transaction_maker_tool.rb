class TextTransactionMakerTool < RubyLLM::Tool
  description "Drafts a transaction from user input without saving"

  def initialize(user, categories_tool)
    @user = user
    @categories_tool = categories_tool
  end

  def execute(attrs)
    attrs = attrs.transform_keys(&:to_sym)

    # If category missing, auto-assign using description
    if attrs[:category].nil? || attrs[:category].is_a?(String)
      attrs[:category] = @categories_tool.execute(description: attrs[:description])
    end

    tx = @user.transactions.new(attrs)
    tx.save
  end
end
