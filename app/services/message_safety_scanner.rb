# Detects contact details and off-platform payment requests. Detection never
# blocks a message; the recipient only sees a translated safety warning.
class MessageSafetyScanner
  EXTERNAL_PAYMENT_PATTERNS = [
    /\bbizum\b/i,
    /\bpaypal\s+friends?\b/i,
    /\bwestern\s+union\b/i,
    /\btransferencia\s+fuera\b/i,
    /\bfuera\s+de\s+la\s+plataforma\b/i
  ].freeze

  IBAN_PATTERN = /[A-Z]{2}\d{2}[A-Z0-9]{11,30}/i
  EMAIL_PATTERN = /[A-Z0-9._%+\-]+@[A-Z0-9.\-]+\.[A-Z]{2,}/i

  def self.call(body)
    new(body).call
  end

  def initialize(body)
    @body = body.to_s
  end

  def call
    { flagged: reasons.any?, reasons: reasons }
  end

  def reasons
    @reasons ||= begin
      found = []
      found << :email if EMAIL_PATTERN.match?(@body)
      found << :phone if phone_number?
      found << :iban if iban?
      found << :external_payment if EXTERNAL_PAYMENT_PATTERNS.any? { |pattern| pattern.match?(@body) }
      found
    end
  end

  private

  def phone_number?
    @body.scan(/\+?\d[\d\s().\-]{7,}\d/).any? do |candidate|
      digits = candidate.gsub(/\D/, "")
      digits.length.between?(9, 15)
    end
  end

  def iban?
    compact = @body.gsub(/\s+/, "").upcase
    compact.scan(IBAN_PATTERN).any? do |candidate|
      candidate.length.between?(15, 34) && candidate[0, 2].match?(/\A[A-Z]{2}\z/)
    end
  end
end
