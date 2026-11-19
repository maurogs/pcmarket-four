class User < ApplicationRecord
  AVATAR_SIZES = { thumb: [ 100, 100 ], medium: [ 300, 300 ] }.freeze
  AVATAR_CONTENT_TYPES = %w[image/png image/jpeg image/jpg image/webp image/gif].freeze
  AVATAR_MAX_SIZE = 5.megabytes

  # Every notification topic the account settings page offers a toggle for.
  NOTIFICATION_KEYS = %w[order_updates messages offers price_drops saved_search_alerts
                         followed_store_listings newsletter].freeze
  # These are on unless the user switches them off; the rest are opt-in.
  TRANSACTIONAL_NOTIFICATION_KEYS = %w[order_updates messages offers].freeze

  # GDPR data exports can be requested at most once per this window.
  EXPORT_THROTTLE = 24.hours

  # Include default devise modules.
  devise :database_authenticatable, :registerable, :recoverable, :rememberable,
         :validatable, :confirmable, :lockable, :trackable,
         :omniauthable, omniauth_providers: %i[google]

  belongs_to :country, optional: true
  has_one :store, dependent: :destroy
  has_many :follows, foreign_key: :follower_id, dependent: :destroy
  has_many :followed_stores, through: :follows, source: :store
  has_many :reviews_written, class_name: "Review", foreign_key: :author_id, dependent: :destroy
  has_many :addresses, dependent: :destroy
  has_one :default_address, -> { where(default_shipping: true) }, class_name: "Address"
  has_one_attached :avatar
  has_one_attached :data_export

  enum :role, { user: 0, admin: 1, moderator: 2 }, default: :user

  validates :username, presence: true, uniqueness: { case_sensitive: false },
                       length: { in: 3..50 },
                       format: { with: /\A[a-z0-9_]+\z/i }
  validates :first_name, :last_name, length: { maximum: 100 }, allow_nil: true
  validates :phone, length: { maximum: 30 }, allow_nil: true
  validates :locale, inclusion: { in: proc { I18n.available_locales.map(&:to_s) } }, allow_nil: true

  validate :avatar_is_a_small_enough_image, if: -> { avatar.attached? }
  validate :notification_preferences_are_valid
  before_save :sync_marketing_opt_in_at

  # True when the user wants `key` sent over `channel`. A per-channel map
  # ({ "newsletter" => { "email" => true } }) wins over the flat one the
  # settings form writes; anything unset falls back to the default above.
  def notify?(key, channel = :email)
    key = key.to_s
    stored = notification_preferences[key]
    stored = stored[channel.to_s] if stored.is_a?(Hash)
    return stored if [ true, false ].include?(stored)

    TRANSACTIONAL_NOTIFICATION_KEYS.include?(key)
  end

  # Google-only accounts have no usable password, so the profile form hides
  # the email field (changing it would strand them without a confirmation).
  def omniauth_only?
    provider.present? && encrypted_password.blank?
  end

  def full_name
    [ first_name, last_name ].compact_blank.join(" ").presence || username
  end

  def display_name
    full_name
  end

  def following?(store)
    store.present? && follows.exists?(store_id: store.id)
  end

  # --- GDPR (Phase 2 step 6) ---------------------------------------------------

  # Accounts::Deleter anonymizes the row instead of destroying it (reviews keep
  # their author FK), so "deleted" is a timestamp, not a missing record.
  def deleted?
    deleted_at.present?
  end

  # Deleted accounts must never get a session back — not through the sign-in
  # form, not through a remember-me cookie.
  def active_for_authentication?
    super && !deleted?
  end

  # Mapped to devise.failure.deleted in every locale by Warden's failure app.
  def inactive_message
    deleted? ? :deleted : super
  end

  # True while the once-per-EXPORT_THROTTLE window is still running.
  def data_export_throttled?
    data_export_generated_at.present? && data_export_generated_at > EXPORT_THROTTLE.ago
  end

  # Creates or finds a user from a Google OAuth identity.
  def self.from_omniauth(auth)
    raise ArgumentError, "missing provider info" unless auth&.provider && auth&.uid

    where(provider: auth.provider, uid: auth.uid).first_or_initialize.tap do |user|
      user.provider = auth.provider
      user.uid = auth.uid
      user.email = auth.info.email.presence || user.email
      user.first_name ||= auth.info.first_name
      user.last_name ||= auth.info.last_name
      if user.new_record?
        name_base = [ auth.info.first_name, auth.info.last_name ].compact_blank.join("_")
        email_base = auth.info.email.to_s.split("@").first
        user.username = generate_username(name_base.presence || email_base.presence || "user#{uid[-5..]}")
        user.password = Devise.friendly_token(72)
        user.skip_confirmation!
        user.locale = I18n.locale.to_s
      end
      user.save!
    end
  end

  def self.generate_username(base)
    base = base.to_s.downcase.gsub(/[^a-z0-9]+/, "_").squeeze("_").gsub(/\A_+|_+\z/, "")[0, 40]
    base = "user" if base.blank?
    candidate = base
    candidate = "#{base}_#{SecureRandom.hex(3)}" while where(username: candidate).exists?
    candidate
  end

  private

  def avatar_is_a_small_enough_image
    return unless avatar.blob

    unless AVATAR_CONTENT_TYPES.include?(avatar.blob.content_type)
      errors.add(:avatar, :invalid_content_type)
    end
    errors.add(:avatar, :too_large) if avatar.blob.byte_size > AVATAR_MAX_SIZE
  end

  # Accepts the flat form the settings form writes (key => boolean) and the
  # per-channel form notify? understands (key => { channel => boolean }).
  def notification_preferences_are_valid
    return if notification_preferences.is_a?(Hash) &&
              notification_preferences.all? { |key, value| valid_notification_value?(key, value) }

    errors.add(:notification_preferences, :invalid)
  end

  def valid_notification_value?(key, value)
    return false unless NOTIFICATION_KEYS.include?(key)
    return true if [ true, false ].include?(value)

    value.is_a?(Hash) && value.values.all? { |enabled| [ true, false ].include?(enabled) }
  end

  def sync_marketing_opt_in_at
    if marketing_opt_in
      self.marketing_opt_in_at ||= Time.current
    else
      self.marketing_opt_in_at = nil
    end
  end
end
