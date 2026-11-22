class ApiToken < ApplicationRecord
  DEFAULT_TTL = 90.days
  TOUCH_INTERVAL = 1.hour

  belongs_to :user, inverse_of: :api_tokens

  attr_reader :plain_token

  validates :token_digest, presence: true, uniqueness: true

  scope :active, -> { where("expires_at IS NULL OR expires_at > ?", Time.current) }

  class << self
    def digest(raw_token)
      Digest::SHA256.hexdigest(raw_token.to_s)
    end

    def issue!(user:, name: nil, expires_at: nil)
      raw_token = SecureRandom.urlsafe_base64(32)
      token = create!(
        user: user,
        name: name,
        token_digest: digest(raw_token),
        expires_at: expires_at || DEFAULT_TTL.from_now
      )
      token.instance_variable_set(:@plain_token, raw_token)
      token
    end

    def authenticate(raw_token)
      return nil if raw_token.blank?

      active.find_by(token_digest: digest(raw_token))
    end
  end

  def expired?
    expires_at.present? && expires_at <= Time.current
  end

  def active?
    !expired?
  end

  def touch_last_used!
    return if last_used_at.present? && last_used_at > TOUCH_INTERVAL.ago

    update_columns(last_used_at: Time.current, updated_at: Time.current)
  end
end
