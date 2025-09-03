class MessagesController < ApplicationController
  def index
    @messages = current_user.messages.all.order(created_at: :asc)
    @user_message = Message.new
  end

  def create
    @user_message = Message.create(content: message_params[:content] || "Receipt", role: 'user', user: current_user, file: message_params[:file])

    instructions = @user_message.build_content
    build_conversation_history
    history = PastTransactionTool.new(current_user)
    categories = CategoriesTool.new(current_user)
     if @user_message.file.attached?
       @response= send_picture(model: "gemini-2.5-flash", with: { file: @user_message.file.url }).content
      @ai_message = Message.create(content: @response, role: 'assistant', user: current_user)
     end

     unless @user_message.file.attached?
        transaction_maker = TextTransactionMakerTool.new(current_user, CategoriesFinderTool.new(current_user))
        response = @ruby_llm_chat.with_tools(categories, history, transaction_maker).with_instructions(instructions).ask(@user_message.content).content
        @ai_message = Message.create(content: response, role: 'assistant', user: current_user)
     end

    if @ai_message.valid?
        respond_to do |format|
          format.html { redirect_to messages_path }

          format.turbo_stream do
            render turbo_stream: [
              turbo_stream.append("messages",
                partial: "partials/message", locals: { message: @user_message }
              ),
              turbo_stream.append("messages",
                partial: "partials/message", locals: { message: @ai_message }
              ),
              turbo_stream.replace("chat_dashboard",
                partial: "partials/chat_form", locals: { user_message: Message.new }
              )
            ]
          end
        end
          # format.html { redirect_to messages_path }
    else
      render :index, status: :unprocessable_entity
    end
  end


  def build_conversation_history
    @ruby_llm_chat = RubyLLM.chat(model: 'gemini-2.5-flash')
    current_user.messages.all.each do |message|
      @ruby_llm_chat.add_message(content: message.content, role: message.role)
    end
  end

  def send_picture(model: "gemini-2.5-flash", with: {})
    instruction = " Drafts a transaction from user input without saving with description of transaction (2-3 words)), amount (the monetary value), must be either expense or income, the transaction date, and select a category of the transaction based on description from this categories #{Category.pluck(:title).join(', ')}. Only confirm after this to add it in the transaction table."
    @chat = RubyLLM.chat(model: model)
    @response = @chat.with_instructions(instruction).ask(@user_message.content , with: with)
  end

  private

  def message_params
    params.require(:message).permit(:content, :file)
  end
end

# "Get me the date, total and make a category for the transaction which is included in this [ 'Food', 'Health', 'Commute', 'Utilities', 'Entertainment', 'Others']. and then give it a name for the transaction."
