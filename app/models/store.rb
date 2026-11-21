class Store < ApplicationRecord
  extend FriendlyId
  friendly_id :name, use: [ :slugged, :history ]

  LOGO_MAX_BYTES = 5.megabytes
  BANNER_MAX_BYTES = 8.megabytes
  IMAGE_CONTENT_TYPES = %w[image/jpeg image/png image/webp].freeze

  belongs_to :user, inverse_of: :store
  belongs_to :region, optional: true, inverse_of: :stores

  has_many :listings, dependent: :nullify, inverse_of: :store
  has_many :follows, dependent: :destroy, inverse_of: :store
  has_many :followers, through: :follows, source: :follower
  has_many :orders, dependent: :nullify, inverse_of: :store
  has_many :reviews, dependent: :destroy, inverse_of: false

  has_one_attached :logo
  has_one_attached :banner

  enum :store_type, { individual: 0, professional: 1 }

  validates :name, presence: true, length: { minimum: 3, maximum: 50 }
  validates :name, uniqueness: { case_sensitive: false }
  validates :description, length: { maximum: 2000 }, allow_blank: true
  validates :user_id, uniqueness: true
  validate :professional_details_required
  validate :tax_id_format
  validate :logo_within_limits
  validate :banner_within_limits

  scope :verified, -> { where(verified: true) }
  scope :available, -> { where(vacation_mode: false) }

  before_save :archive_previous_slug, if: -> { persisted? && will_save_change_to_slug? }

  def recalculate_rating!
    published_reviews = Review.where(store_id: id, published: true)
    update_columns(
      rating_avg: published_reviews.average(:rating)&.round(2) || 0,
      reviews_count: published_reviews.count,
      updated_at: Time.current
    )
  end

  def on_vacation?
    vacation_mode?
  end

  def for_sale_count
    listings.visible.count
  end

  def sold_count
    listings.sold.count
  end

  def location
    [ city, region&.name, country_code ].compact_blank.uniq.join(", ")
  end

  # Percentage (0..100) of the four seller profile pillars that are complete.
  def completeness
    completeness_checks.count { |_key, done| done } * 25
  end

  def completeness_checks
    {
      logo: logo.attached?,
      description: description.present?,
      policies: return_policy.present? && shipping_policy.present?,
      location: city.present? && (region_id.present? || country_code.present?)
    }
  end

  def to_s
    name
  end

  def should_generate_new_friendly_id?
    name_changed? || slug.blank?
  end

  private

  def archive_previous_slug
    previous = slug_in_database
    return if previous.blank?

    FriendlyId::Slug.find_or_create_by!(sluggable: self, slug: previous)
  rescue ActiveRecord::RecordNotUnique
    nil
  end

  def professional_details_required
    return unless professional?

    errors.add(:company_name, :blank) if company_name.blank?
    errors.add(:tax_id, :blank) if tax_id.blank?
  end

  def tax_id_format
    return if tax_id.blank?
    return unless country_code == "ES"
    return if SpanishTaxIdValidator.valid?(tax_id)

    errors.add(:tax_id, :invalid)
  end

  def logo_within_limits
    validate_attachment(:logo, LOGO_MAX_BYTES)
  end

  def banner_within_limits
    validate_attachment(:banner, BANNER_MAX_BYTES)
  end

  def validate_attachment(name, max_bytes)
    attachment = public_send(name)
    return unless attachment.attached?

    errors.add(name, :invalid_format) unless IMAGE_CONTENT_TYPES.include?(attachment.content_type)
    errors.add(name, :too_large) if attachment.byte_size.to_i > max_bytes
  end
end
