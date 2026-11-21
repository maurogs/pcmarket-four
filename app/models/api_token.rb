class ApiToken < ApplicationRecord
  belongs_to :user, inverse_of: :api_tokens

  has_secure_token :token

  validates :token, presence: true, uniqueness: true

  scope :active, -> { where("expires_at IS NULL OR expires_at > ?", Time.current) }

  def expired?
    expires_at.present? && expires_at <= Time.current
  end

  def active?
    !expired?
  end

  def touch_last_used!
    update_columns(last_used_at: Time.current, updated_at: Time.current)
  end
end
