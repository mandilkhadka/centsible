class CategoriesTool < RubyLLM::Tool
  description "Gets category_titles through category_id"

  def initialize(user)
    @user = user
  end

  def execute
    categories = @user.categories
    categories.select(:title, :id).as_json
  end
end
