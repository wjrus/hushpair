module ContentSafety
  EMAIL_PATTERN = /\b[A-Z0-9._%+\-]+@[A-Z0-9.\-]+\.[A-Z]{2,}\b/i
  URL_PATTERN = %r{\b(?:https?://|www\.)\S+\b}i
  PHONE_PATTERN = /(?:\+?\d[\d\-\(\) ]{7,}\d)/
  HANDLE_PATTERN = /(?:^|\s)@[a-z0-9_]{2,}/i
  LEET_SUBSTITUTIONS = {
    "0" => "o",
    "1" => "i",
    "3" => "e",
    "4" => "a",
    "5" => "s",
    "7" => "t",
    "8" => "b",
    "!" => "i",
    "$" => "s",
    "@" => "a"
  }.freeze

  PROHIBITED_NICKNAME_TOKENS = %w[
    asshole bastard bitch cunt dick fuck faggot fag gook hitler kike kkk nazi neonazi
    nigga nigger pedo pedophile rapist rape spic swastika whore slut
  ].freeze

  PROHIBITED_NICKNAME_PHRASES = %w[
    gasjews heilhitler killalljews siegheil whitepower
  ].freeze

  PROTECTED_TARGET_TERMS = %w[
    asian autistic black disabled gay immigrant islam jew jewish lesbian mexican muslim queer trans transgender
  ].freeze

  ABUSIVE_MODIFIER_TERMS = %w[
    death destroy destroyer exterminate exterminator gas genocide hang hate hater kill killer lynch murder murderer rape rapist
  ].freeze

  module_function

  def contains_contact_info?(text)
    value = text.to_s.strip
    return false if value.blank?

    [ EMAIL_PATTERN, URL_PATTERN, PHONE_PATTERN, HANDLE_PATTERN ].any? { |pattern| value.match?(pattern) }
  end

  def prohibited_nickname?(text)
    value = text.to_s.strip
    return false if value.blank?

    normalized = normalize_nickname(value)
    tokens = normalized.split
    compact = normalized.delete(" ")

    PROHIBITED_NICKNAME_TOKENS.any? { |term| tokens.include?(term) } ||
      PROHIBITED_NICKNAME_PHRASES.any? { |term| compact.include?(term) } ||
      targeted_abuse?(compact)
  end

  def safe_nickname(text)
    value = text.to_s.strip
    return nil if value.blank?
    return nil if contains_contact_info?(value) || prohibited_nickname?(value)

    value
  end

  def normalize_nickname(value)
    value
      .downcase
      .chars
      .map { |character| LEET_SUBSTITUTIONS.fetch(character, character) }
      .join
      .gsub(/[^a-z0-9]+/, " ")
      .squeeze(" ")
      .strip
  end

  def targeted_abuse?(compact_value)
    PROTECTED_TARGET_TERMS.any? { |term| compact_value.include?(term) } &&
      ABUSIVE_MODIFIER_TERMS.any? { |term| compact_value.include?(term) }
  end
end
