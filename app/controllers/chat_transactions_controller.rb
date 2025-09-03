class ChatTransactionsController < ApplicationController
  include ActionView::Helpers::NumberHelper

  def confirm
    return redirect_to messages_path, alert: "No draft payload." if params[:payload].blank?

    draft = verifier.verify(params[:payload]) # raises if tampered

    desc   = draft["description"].to_s.strip
    amount = draft["amount"].is_a?(String) ? draft["amount"].gsub(/[,_]/, "").to_i : draft["amount"].to_i
    ttype  = draft["transaction_type"].to_s
    dstr   = draft["date"].to_s
    title  = draft["category_title"].to_s

    date =
      begin
        Date.parse(dstr)
      rescue ArgumentError, TypeError
        Date.current
      end

    category = find_or_guess_category(title)

    tx = current_user.transactions.create!(
      description: desc,
      amount: amount,
      transaction_type: ttype,
      date: date,
      category: category
    )

    flash.now[:notice] = "Saved: #{number_to_currency(tx.amount, unit: '¥', precision: 0)} • #{category&.title} • #{tx.date}"

    # If the request came from a Turbo Frame, render HTML for that frame.
    if turbo_frame_request?
      render partial: "partials/confirm_bar", locals: { draft: nil, signed_draft: nil }
    else
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            "confirm_bar",
            partial: "partials/confirm_bar",
            locals: { draft: nil, signed_draft: nil }
          )
        end
        format.html { redirect_to messages_path, notice: "Transaction saved." }
      end
    end
  rescue ActiveSupport::MessageVerifier::InvalidSignature
    redirect_to messages_path, alert: "Draft expired or invalid."
  end

  def dismiss
    if turbo_frame_request?
      render partial: "partials/confirm_bar", locals: { draft: nil, signed_draft: nil }
    else
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            "confirm_bar",
            partial: "partials/confirm_bar",
            locals: { draft: nil, signed_draft: nil }
          )
        end
        format.html { redirect_to messages_path }
      end
    end
  end

  private

  def verifier
    Rails.application.message_verifier(:draft_tx)
  end

  def find_or_guess_category(title)
    title = title.to_s.strip
    return current_user.categories.find_or_create_by(title: "Others") if title.blank?

    current_user.categories.find_by(title: title) ||
      current_user.categories.where("LOWER(title) LIKE ?", "%#{title.downcase}%").first ||
      current_user.categories.find_or_create_by(title: "Others")
  end
end
