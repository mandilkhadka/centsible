module MessagesHelper
  def extract_draft_tx(raw)
    return nil unless raw
    # Match ```DRAFT_TX ... ```
    if raw =~ /```DRAFT_TX\s*(\{.*?\})\s*```/m
      json = $1
      JSON.parse(json)
    end
  rescue JSON::ParserError
    nil
  end
end
