# app/controllers/messages_controller.rb
class MessagesController < ApplicationController
  include MessagesHelper

  def index
    @messages = current_user.messages.order(:created_at).last(6)
    @user_message = Message.new
    @draft_payload = nil
  end

  def create
    # Support both plain text and file (picture/voice) messages
    @user_message = Message.create!(
      content: message_params[:content].presence || "Receipt",
      role: 'user',
      user: current_user,
      file: message_params[:file]
    )

    instructions = @user_message.build_content
    build_conversation_history

    history = PastTransactionTool.new(current_user)

    # Ask the model. If a file is attached, pass it via `with:` so vision/ASR can be used.
    response =
      if @user_message.file&.attached?
        @ruby_llm_chat
          .with_tools(history)
          .with_instructions(instructions)
          .ask(@user_message.content, with: { file: @user_message.file.url })
          .content
      else
        @ruby_llm_chat
          .with_tools(history)
          .with_instructions(instructions)
          .ask(@user_message.content)
          .content
      end

    @ai_message = Message.create!(content: response, role: 'assistant', user: current_user)

    # Try to extract a DRAFT_TX block from the assistant response
    draft = extract_draft_tx(response)
    signed_draft = draft.present? ? verifier.generate(draft) : nil

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.append("messages", partial: "partials/message", locals: { message: @user_message }),
          turbo_stream.append("messages", partial: "partials/message", locals: { message: @ai_message }),
          turbo_stream.replace("chat_dashboard", partial: "partials/chat_form", locals: { user_message: Message.new }),

          turbo_stream.update(
            "confirm_bar",
            render_to_string(partial: "partials/confirm_bar", locals: { draft: draft, signed_draft: signed_draft })
          )
        ]
      end

      format.html { redirect_to messages_path }
    end
  end

  private

  def build_conversation_history
    @ruby_llm_chat = RubyLLM.chat(model: 'gemini-2.5-flash')
    current_user.messages.order(created_at: :desc).limit(20).reverse.each do |message|
      @ruby_llm_chat.add_message(content: message.content, role: message.role)
    end
  end

  # For signing/verifying the draft payload (confirm button)
  def verifier
    Rails.application.message_verifier(:draft_tx)
  end

  def message_params
    params.require(:message).permit(:content, :file)
  end
end
