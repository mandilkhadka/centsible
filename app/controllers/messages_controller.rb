class MessagesController < ApplicationController
  def index
    @messages = current_user.messages.all.order(created_at: :asc)
    @user_message = Message.new
  end

  def create
    user_message = Message.create(content: message_params[:content], role: 'user', user: current_user)
    instructions = user_message.build_content
    build_conversation_history
    response = @ruby_llm_chat.with_instructions(instructions).ask(user_message.content).content
    @ai_message = Message.create(content: response, role: 'assistant', user: current_user)
    if @ai_message
      redirect_to messages_path
    else
      render :index, status: :unprocessable_entity
    end
  end

  def build_conversation_history
    @ruby_llm_chat = RubyLLM.chat(model: 'gemini-2.0-flash')
    Message.all.each do |message|
      @ruby_llm_chat.add_message(content: message.content, role: message.role)
    end
    @ruby_llm_chat = RubyLLM.chat(model: 'gemini-2.0-flash')
    current_user.transactions.each do |transaction|
      content = {
        description: transaction.description,
        amount: transaction.amount,
        date: transaction.date,
        category: transaction.category
      }.to_json
      @ruby_llm_chat.add_message(content: content, role: 'user')
    end
  end

  private

  def message_params
    params.require(:message).permit(:content)
  end
end
