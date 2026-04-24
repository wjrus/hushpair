module ContentSafety
  EMAIL_PATTERN = /\b[A-Z0-9._%+\-]+@[A-Z0-9.\-]+\.[A-Z]{2,}\b/i
  URL_PATTERN = %r{\b(?:https?://|www\.)\S+\b}i
  PHONE_PATTERN = /(?:\+?\d[\d\-\(\) ]{7,}\d)/
  HANDLE_PATTERN = /(?:^|\s)@[a-z0-9_]{2,}/i

  module_function

  def contains_contact_info?(text)
    value = text.to_s.strip
    return false if value.blank?

    [ EMAIL_PATTERN, URL_PATTERN, PHONE_PATTERN, HANDLE_PATTERN ].any? { |pattern| value.match?(pattern) }
  end
end
