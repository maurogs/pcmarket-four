class ProfanityFilter
  SEPARATOR = ",".freeze

  class << self
    def blocked_words
      Setting.get("blocked_words", "").to_s.split(SEPARATOR)
             .map { |word| word.strip.downcase }
             .reject(&:blank?)
    end

    def blocked?(text)
      return false if text.blank?

      normalised = text.to_s.downcase
      blocked_words.any? { |word| normalised.include?(word) }
    end
  end
end
