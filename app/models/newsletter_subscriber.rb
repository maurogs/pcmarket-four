class NewsletterSubscriber < ApplicationRecord
  EMAIL_FORMAT = URI::MailTo::EMAIL_REGEXP

  has_secure_token :token

  validates :email, presence: true, format: { with: EMAIL_FORMAT },
                    uniqueness: { case_sensitive: false }
  validates :locale, inclusion: { in: ->(_) { I18n.available_locales.map(&:to_s) } }

  scope :confirmed, -> { where.not(confirmed_at: nil).where(unsubscribed_at: nil) }
  scope :pending, -> { where(confirmed_at: nil, unsubscribed_at: nil) }

  before_validation :normalise_email
  before_validation :normalise_locale

  def confirmed?
    confirmed_at.present? && unsubscribed_at.nil?
  end

  def confirm!
    update!(confirmed_at: Time.current, unsubscribed_at: nil)
  end

  def unsubscribe!
    update!(unsubscribed_at: Time.current)
  end

  private

  def normalise_email
    self.email = email.to_s.strip.downcase if email.present?
  end

  def normalise_locale
    self.locale = I18n.default_locale.to_s if locale.blank?
  end
end
