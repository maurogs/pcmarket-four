# Verifies a Google ID token with Google's tokeninfo endpoint and maps it to a
# local user. Network access is stubbed with WebMock in tests.
class GoogleTokenVerifier
  ENDPOINT = "https://oauth2.googleapis.com/tokeninfo"
  TIMEOUT = 5
  ALLOWED_ISSUERS = %w[accounts.google.com https://accounts.google.com].freeze

  class Error < StandardError; end

  class << self
    def allowed_client_ids
      values = ENV.fetch("GOOGLE_CLIENT_IDS", "").split(",") + [ ENV["GOOGLE_CLIENT_ID"] ]
      values.map(&:to_s).map(&:strip).reject(&:blank?).uniq
    end

    def configured?
      allowed_client_ids.any?
    end
  end

  def initialize(id_token)
    @id_token = id_token.to_s
  end

  def payload
    raise Error, "not_configured" unless self.class.configured?
    raise Error, "missing_token" if @id_token.blank?

    response = HTTP.timeout(TIMEOUT).get(ENDPOINT, params: { id_token: @id_token })
    raise Error, "invalid_token" unless response.status.success?

    data = JSON.parse(response.to_s)
    validate_claims!(data)
    data
  rescue HTTP::Error, JSON::ParserError, Timeout::Error
    raise Error, "verification_failed"
  end

  private

  def validate_claims!(data)
    unless self.class.allowed_client_ids.include?(data["aud"].to_s)
      raise Error, "invalid_audience"
    end
    raise Error, "email_unverified" unless GoogleEmailVerification.verified?(data["email_verified"])
    raise Error, "invalid_issuer" unless ALLOWED_ISSUERS.include?(data["iss"].to_s)
    raise Error, "expired" unless data["exp"].present? && data["exp"].to_i > Time.current.to_i
  end
end
