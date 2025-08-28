
class CategoriesTool < RubyLLM::Tool
  def initialize(user)
    @user = user
  end

  def execute
    categories = @user.categories
    categories.select(:title, :id).as_json
  end
end
