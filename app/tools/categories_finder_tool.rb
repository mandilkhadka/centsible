class CategoriesFinderTool < RubyLLM::Tool
  description "Finds a category based on a description"

  def initialize(user)
    @user = user
  end

  def execute(description)
    chat = @ruby_llm_chat = RubyLLM.chat(model: 'gemini-2.5-flash')

    sorted_description = chat.ask("which category does #{description} belong to? #{Category.pluck(:title).join(", ")} answer in only 1 word").content.strip

    category = @user.categories.find_by("LOWER(title) = ?", sorted_description)
    unless category
      category = @user.categories.where("LOWER(title) LIKE ?", "%#{sorted_description}%").first
    end
    category ||= @user.categories.find_or_create_by(title: "Others")

    category
  end
end
