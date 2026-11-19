class User < ApplicationRecord
  AVATAR_SIZES = { thumb: [ 100, 100 ], medium: [ 300, 300 ] }.freeze

  # Include default devise modules.
  devise :database_authenticatable, :registerable, :recoverable, :rememberable,
         :validatable, :confirmable, :lockable, :trackable,
         :omniauthable, omniauth_providers: %i[google]

  belongs_to :country, optional: true
  has_one :store, dependent: :destroy
  has_one_attached :avatar

  enum :role, { user: 0, admin: 1, moderator: 2 }, default: :user

  validates :username, presence: true, uniqueness: { case_sensitive: false },
                       length: { in: 3..50 },
                       format: { with: /\A[a-z0-9_]+\z/i }
  validates :first_name, :last_name, length: { maximum: 100 }, allow_nil: true
  validates :phone, length: { maximum: 30 }, allow_nil: true
  validates :locale, inclusion: { in: proc { I18n.available_locales.map(&:to_s) } }, allow_nil: true

  def full_name
    [ first_name, last_name ].compact_blank.join(" ").presence || username
  end

  def display_name
    full_name
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
end
