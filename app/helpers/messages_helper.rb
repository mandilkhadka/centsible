module MessagesHelper
  # existing extractor (keep yours if you already added it)
  def extract_draft_tx(raw)
    return nil unless raw
    if raw =~ /```DRAFT_TX\s*(\{.*?\})\s*```/m
      json = $1.dup
      json.gsub!(/("amount"\s*:\s*)(\d{1,3}(?:,\d{3})+)/) { "#{$1}#{$2.delete(',')}" }
      json.gsub!(/("amount"\s*:\s*")(\d{1,3}(?:,\d{3})+)(")/) { %Q(#{$1}#{$2.delete(',')}#{$3}) }
      JSON.parse(json)
    end
  rescue JSON::ParserError
    nil
  end

  # NEW: remove the fenced JSON block and the short confirm sentence that follows it
  def strip_draft_block(text)
    return "" if text.blank?
    s = text.dup
    # remove the fenced block
    s.gsub!(/```DRAFT_TX.*?```/m, "")
    # clean the one-line confirm prompt that may follow (e.g., "Confirm to save?" / "Confirm?")
    s.gsub!(/\n?\s*(Confirm( to save)?\??)\s*$/i, "")
    # compress extra blank lines
    s.gsub!(/\n{3,}/, "\n\n")
    s.strip
  end
end
