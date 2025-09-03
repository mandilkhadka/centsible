# app/controllers/chat_transactions_controller.rb
class ChatTransactionsController < ApplicationController
  include ActionView::Helpers::NumberHelper

  def confirm
    draft = verifier.verify(params[:payload]) # raises if tampered

    # Basic presence checks
    desc  = draft["description"].to_s.strip
    amt   = draft["amount"].to_i
    ttype = draft["transaction_type"].to_s
    dstr  = draft["date"].to_s
    ctitle = draft["category_title"].to_s

    # Parse date safely (fallback to today if parsing fails)
    date =
      begin
        Date.parse(dstr)
      rescue ArgumentError, TypeError
        Date.current
      end

    category = find_or_guess_category(ctitle)

    tx = current_user.transactions.create!(
      description: desc,
      amount: amt,
      transaction_type: ttype, # "expense" or "income"
      date: date,
      category: category
    )

    # Clear the confirm bar via Turbo; also show a concise flash
    respond_to do |format|
      format.turbo_stream do
        flash.now[:notice] =
          "Saved: #{number_to_currency(tx.amount, unit: '¥', precision: 0)} • #{category&.title} • #{tx.date}"
        render turbo_stream: turbo_stream.replace(
          "confirm_bar",
          partial: "partials/confirm_bar",
          locals: { draft: nil, signed_draft: nil }
        )
      end
      format.html { redirect_to messages_path, notice: "Transaction saved." }
    end
  rescue ActiveSupport::MessageVerifier::InvalidSignature
    redirect_to messages_path, alert: "Draft expired or invalid."
  end

  def dismiss
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

  private

  def verifier
    Rails.application.message_verifier(:draft_tx)
  end

  # Works in both Postgres (ILIKE) and SQLite (LOWER LIKE)
  def find_or_guess_category(title)
    title = title.to_s.strip
    return current_user.categories.find_or_create_by(title: "Others") if title.blank?

    current_user.categories.find_by(title: title) ||
      current_user.categories.where("LOWER(title) LIKE ?", "%#{title.downcase}%").first ||
      current_user.categories.find_or_create_by(title: "Others")
  end
end
