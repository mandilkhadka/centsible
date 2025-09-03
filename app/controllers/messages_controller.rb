# app/controllers/messages_controller.rb
class MessagesController < ApplicationController
  include MessagesHelper

  def index
    @messages = current_user.messages.order(:created_at)
    @user_message = Message.new
    @draft_payload = nil # nothing yet
  end

  def create
    @user_message = Message.create!(content: message_params[:content], role: 'user', user: current_user)

    instructions = @user_message.build_content
    build_conversation_history
    history    = PastTransactionTool.new(current_user)
    categories = CategoriesFinderTool.new(current_user)
    tx_maker   = TextTransactionMakerTool.new(current_user, CategoriesFinderTool.new(current_user))

    response = @ruby_llm_chat
      .with_tools(categories, history, tx_maker) # unchanged
      .with_instructions(instructions)
      .ask(@user_message.content)
      .content

    @ai_message = Message.create!(content: response, role: 'assistant', user: current_user)

    # NEW: try to extract a draft
    draft = extract_draft_tx(response)

    # Sign payload if present (so we don’t store anything server-side)
    signed_draft = draft.present? ? verifier.generate(draft) : nil

    respond_to do |format|
      format.turbo_stream do
        streams = [
          turbo_stream.append("messages", partial: "partials/message", locals: { message: @user_message }),
          turbo_stream.append("messages", partial: "partials/message", locals: { message: @ai_message }),
          turbo_stream.replace("chat_dashboard", partial: "partials/chat_form", locals: { user_message: Message.new })
        ]
        # NEW: render confirm bar if we have a draft
        streams << turbo_stream.replace("confirm_bar",
          partial: "partials/confirm_bar",
          locals: { draft: draft, signed_draft: signed_draft }
        )

        render turbo_stream: streams
      end
      format.html { redirect_to messages_path }
    end
  end

  private

  def verifier
    # namespacing for this feature
    Rails.application.message_verifier(:draft_tx)
  end

  def message_params
    params.require(:message).permit(:content)
  end
end
