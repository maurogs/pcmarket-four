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

  enum :role, { user: 0, moderator: 1, admin: 2 }
  enum :status, { active: 0, suspended: 1, banned: 2 }

  has_one_attached :avatar
  has_one :store, dependent: :destroy, inverse_of: :user

  belongs_to :country, foreign_key: :country_code, primary_key: :code, inverse_of: :users, optional: true
  belongs_to :region, optional: true

  has_many :listings, dependent: :destroy, inverse_of: :user
  has_many :favorites, dependent: :destroy, inverse_of: :user
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

  validates :username, presence: true, uniqueness: { case_sensitive: false }, length: { maximum: 40 }
  validates :country_code, presence: true
  validates :locale, inclusion: { in: ->(_) { I18n.available_locales.map(&:to_s) } }

  before_validation :assign_username, on: :create, if: -> { username.blank? }
  before_validation :normalise_locale

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

  def full_name
    [ first_name, last_name ].compact_blank.join(" ").presence || username
  end

  def active_account?
    active? && deleted_at.nil?
  end

  def staff?
    moderator? || admin?
  end

  def deleted?
    deleted_at.present?
  end

  def soft_delete!
    update_columns(deleted_at: Time.current, updated_at: Time.current)
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
end
