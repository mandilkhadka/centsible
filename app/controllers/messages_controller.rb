class MessagesController < ApplicationController
  require 'redcarpet'
  
  def index
    @messages = Message.all
    @user_message = Message.new
  end

  def create
    user_message = Message.create(content: message_params[:content], role: 'user', user: current_user)
    instructions = user_message.build_content
    build_conversation_history
    tool = PastExpenseTool.new(current_user)
    response = @ruby_llm_chat.with_instructions(instructions).with_tool(tool).ask(user_message.content).content
    @ai_message = Message.create(content: response, role: 'assistant', user: current_user)
    if @ai_message
      redirect_to messages_path
    else
      render :index, status: :unprocessable_entity
    end
  end

  def build_conversation_history
    @ruby_llm_chat = RubyLLM.chat(model: 'gemini-2.0-flash')
    current_user.messages.where(role: 'user').each do |message|
      @ruby_llm_chat.add_message(content: message.content, role: message.role)
    end
  end

  private

  def message_params
    params.require(:message).permit(:content)
  end
end
