class User < ApplicationRecord
  USERNAME_ADJECTIVES = %w[
    Amber Bold Brave Calm Clever Cosmic Crimson Crystal Dawn Electric Emerald
    Frozen Gentle Golden Hidden Iron Jade Lunar Mighty Neon Noble Pixel Quantum
    Rapid Royal Rusty Shadow Silent Silver Solar Stormy Swift Turbo Velvet Wild
  ].freeze

  USERNAME_ANIMALS = %w[
    Badger Bison Cobra Condor Crane Dragon Eagle Falcon Fox Gecko Hawk Heron
    Ibis Jaguar Koala Lynx Moose Orca Otter Owl Panda Panther Phoenix Puma
    Raven Shark Sparrow Tiger Turtle Viper Wolf
  ].freeze

  devise :database_authenticatable, :registerable, :recoverable, :rememberable,
         :validatable, :confirmable, :trackable, :lockable, :omniauthable,
         omniauth_providers: [ :google_oauth2 ]

  NOTIFICATION_EMAIL_KEYS = %w[
    email_messages email_offers email_order_updates
    email_saved_search_alerts email_price_drops_favourites
  ].freeze
  USERNAME_FORMAT = /\A[A-Za-z0-9\-_#]{3,30}\z/
  PHONE_FORMAT = /\A\+?[1-9]\d{6,14}\z/

  enum :role, { user: 0, moderator: 1, admin: 2 }
  enum :status, { active: 0, suspended: 1, banned: 2 }

  has_one_attached :avatar
  has_one :store, dependent: :destroy, inverse_of: :user

  belongs_to :country, foreign_key: :country_code, primary_key: :code, inverse_of: :users, optional: true
  belongs_to :region, optional: true

  has_many :listings, dependent: :destroy, inverse_of: :user
  has_many :favorites, dependent: :destroy, inverse_of: :user
  has_many :cart_items, dependent: :destroy, inverse_of: false
  has_many :favorite_listings, through: :favorites, source: :listing
  has_many :follows, foreign_key: :follower_id, dependent: :destroy, inverse_of: :follower
  has_many :followed_stores, through: :follows, source: :store
  has_many :addresses, dependent: :destroy, inverse_of: :user
  has_many :saved_searches, dependent: :destroy, inverse_of: :user
  has_many :notifications, dependent: :destroy, inverse_of: :user
  has_many :api_tokens, dependent: :destroy, inverse_of: :user
  has_many :sell_offers, dependent: :destroy, inverse_of: :user
  has_many :reviews, foreign_key: :reviewer_id, dependent: :destroy, inverse_of: :reviewer
  has_many :reports, foreign_key: :reporter_id, dependent: :destroy, inverse_of: :reporter

  has_many :conversations_as_buyer, class_name: "Conversation", foreign_key: :buyer_id,
                                    dependent: :destroy, inverse_of: :buyer
  has_many :conversations_as_seller, class_name: "Conversation", foreign_key: :seller_id,
                                     dependent: :destroy, inverse_of: :seller
  has_many :messages, foreign_key: :sender_id, dependent: :destroy, inverse_of: :sender
  has_many :blocks_made, class_name: "Block", foreign_key: :blocker_id, dependent: :destroy,
                         inverse_of: :blocker
  has_many :blocks_received, class_name: "Block", foreign_key: :blocked_id, dependent: :destroy,
                             inverse_of: :blocked

  has_many :orders_as_buyer, class_name: "Order", foreign_key: :buyer_id,
                             dependent: :restrict_with_error, inverse_of: :buyer
  has_many :orders_as_seller, class_name: "Order", foreign_key: :seller_id,
                              dependent: :restrict_with_error, inverse_of: :seller

  attr_accessor :terms_accepted, :terms_required

  validates :username, presence: true, uniqueness: { case_sensitive: false },
                       format: { with: USERNAME_FORMAT }
  validates :phone, format: { with: PHONE_FORMAT }, allow_blank: true
  validates :country_code, presence: true
  validates :locale, inclusion: { in: ->(_) { I18n.available_locales.map(&:to_s) } }

  before_validation :assign_username, on: :create, if: -> { username.blank? }
  before_validation :normalise_locale
  before_validation :stamp_terms_acceptance, on: :create
  validate :terms_must_be_accepted, on: :create, if: -> { terms_required }

  scope :visible, -> { where(status: :active, deleted_at: nil) }
  scope :staff, -> { where(role: %i[moderator admin]) }

  def self.from_omniauth(auth)
    info = auth.info
    user = find_by(provider: auth.provider, uid: auth.uid)
    return user if user

    user = find_by(email: info.email.to_s.downcase)
    if user
      user.update!(provider: auth.provider, uid: auth.uid)
      return user
    end

    create!(
      provider: auth.provider,
      uid: auth.uid,
      email: info.email,
      first_name: info.first_name,
      last_name: info.last_name,
      password: Devise.friendly_token[0, 20],
      confirmed_at: Time.current,
      terms_accepted_at: Time.current
    )
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
    nil
  end

  def display_name
    store&.name.presence || username
  end

  def initials
    source = [ first_name, last_name ].compact_blank
    return source.map { |part| part.first.upcase }.join if source.any?

    username.to_s.first(2).upcase
  end

  def full_name
    [ first_name, last_name ].compact_blank.join(" ").presence || username
  end

  def active_account?
    active? && deleted_at.nil?
  end

  def staff?
    moderator? || admin?
  end

  def blocked_by?(other)
    other.present? && blocks_received.exists?(blocker_id: other.id)
  end

  def blocks?(other)
    other.present? && blocks_made.exists?(blocked_id: other.id)
  end

  def blocked_with?(other)
    other.present? && Block.between?(self, other)
  end

  def inbox_unread_count
    Conversation.where(buyer_id: id).or(Conversation.where(seller_id: id))
                .sum(Arel.sql("CASE WHEN buyer_id = #{id.to_i} THEN buyer_unread_count ELSE seller_unread_count END"))
  end

  def deleted?
    deleted_at.present?
  end

  # GDPR erasure: keeps the row (orders are legally retained) but removes
  # personal data and archives every listing.
  def soft_delete!
    transaction do
      avatar.purge if avatar.attached?
      listings.update_all(status: Listing.statuses[:archived], updated_at: Time.current)
      update_columns(
        email: "deleted-#{id}@example.invalid",
        unconfirmed_email: nil,
        username: "deleted-user-#{id}",
        first_name: nil,
        last_name: nil,
        phone: nil,
        deleted_at: Time.current,
        updated_at: Time.current
      )
    end
  end

  def notification_preference_enabled?(key)
    value = notification_preferences.to_h[key.to_s]
    return default_notification_preference(key) if value.nil?

    ActiveModel::Type::Boolean.new.cast(value) == true
  end

  def notify_by_email?(kind)
    key = kind.to_s
    return accepts_marketing? if key == "email_newsletter"

    notification_preference_enabled?(key)
  end

  def update_notification_preferences!(attributes)
    submitted = attributes.to_h.slice(*(NOTIFICATION_EMAIL_KEYS + [ "email_newsletter" ]))
    preferences = notification_preferences.to_h.merge(
      submitted.transform_values { |value| ActiveModel::Type::Boolean.new.cast(value) == true }
    )
    update!(
      notification_preferences: preferences,
      accepts_marketing: preferences["email_newsletter"] == true
    )
  end

  def oauth_only?
    provider.present?
  end

  # Every listing needs a store: the first listing creates an individual store
  # named after the username.
  def ensure_store!
    return store if store.present?

    create_store!(
      name: username.to_s.first(50),
      store_type: :individual,
      country_code: country_code.presence || "ES",
      region_id: region_id,
      city: city
    )
  rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid
    reload.store
  end

  private

  def assign_username
    self.username = loop do
      candidate = "#{USERNAME_ADJECTIVES.sample}-#{USERNAME_ANIMALS.sample}##{rand(1000..9999)}"
      break candidate unless self.class.exists?([ "lower(username) = ?", candidate.downcase ])
    end
  end

  def normalise_locale
    self.locale = I18n.default_locale.to_s if locale.blank?
  end

  def default_notification_preference(key)
    NOTIFICATION_EMAIL_KEYS.include?(key.to_s)
  end

  def stamp_terms_acceptance
    self.terms_accepted_at = Time.current if accepted_terms?
  end

  def accepted_terms?
    ActiveModel::Type::Boolean.new.cast(terms_accepted) == true
  end

  def terms_must_be_accepted
    return if terms_accepted_at.present? || accepted_terms?

    errors.add(:terms_accepted, :accepted)
  end
end
