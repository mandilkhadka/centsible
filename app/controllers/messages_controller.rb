# app/controllers/messages_controller.rb
class MessagesController < ApplicationController
  include MessagesHelper

  def index
    @messages = current_user.messages.order(:created_at)
    @user_message = Message.new
    @draft_payload = nil
  end

  def create
    @user_message = Message.create!(
      content: message_params[:content],
      role: 'user',
      user: current_user
    )

    instructions = @user_message.build_content
    build_conversation_history

    history    = PastTransactionTool.new(current_user)
    categories = CategoriesFinderTool.new(current_user)

    response = @ruby_llm_chat
      .with_tools(history)
      .with_instructions(instructions)
      .ask(@user_message.content)
      .content

    @ai_message = Message.create!(content: response, role: 'assistant', user: current_user)

    draft = extract_draft_tx(response)
    signed_draft = draft.present? ? verifier.generate(draft) : nil

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.append("messages", partial: "partials/message", locals: { message: @user_message }),
          turbo_stream.append("messages", partial: "partials/message", locals: { message: @ai_message }),
          turbo_stream.replace("chat_dashboard", partial: "partials/chat_form", locals: { user_message: Message.new }),
          turbo_stream.replace("confirm_bar", partial: "partials/confirm_bar", locals: { draft: draft, signed_draft: signed_draft })
        ]
      end
      format.html { redirect_to messages_path }
    end
  end

  private

  # Rebuild the LLM chat with prior messages so the model has context
  def build_conversation_history
    @ruby_llm_chat = RubyLLM.chat(model: 'gemini-2.5-flash')
    current_user.messages.order(:created_at).each do |message|
      @ruby_llm_chat.add_message(content: message.content, role: message.role)
    end
  end

  def verifier
    Rails.application.message_verifier(:draft_tx)
  end

  def message_params
    params.require(:message).permit(:content)
  end
end
