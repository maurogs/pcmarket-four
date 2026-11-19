# A seller's public storefront. Created lazily by Stores::EnsureForUser —
# every user who lists something for sale gets exactly one.
class Store < ApplicationRecord
  extend FriendlyId

  # Business identity is only required for business accounts.
  enum :kind, { individual: 0, business: 1 }, default: :individual

  IMAGE_CONTENT_TYPES = [ "image/png", "image/jpeg", "image/webp" ].freeze
  LOGO_MAX_SIZE = 5.megabytes
  BANNER_MAX_SIZE = 8.megabytes

  # Virtual settings-form flags (see #assign_settings).
  attr_accessor :remove_logo, :remove_banner

  belongs_to :user
  belongs_to :country, optional: true
  has_many :listings, dependent: :destroy
  has_many :follows, dependent: :destroy
  has_many :followers, through: :follows, source: :follower
  has_many :reviews, dependent: :destroy

  has_one_attached :logo
  has_one_attached :banner

  friendly_id :slug_source, use: %i[slugged history]

  validates :name, presence: true, length: { in: 2..60 },
                   uniqueness: { case_sensitive: false }
  validates :slug, presence: true, uniqueness: true, allow_nil: true
  validates :bio, length: { maximum: 2000 }
  validates :business_name, :tax_id, presence: true, if: :business?
  validates :tax_id, spanish_tax_id: true
  validates :vacation_message, length: { maximum: 280 }
  validates :rating_avg, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 5 }
  validates :ratings_count, :sales_count, :followers_count, :active_listings_count,
    numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  validate :logo_is_a_valid_image, if: -> { logo.attached? }
  validate :banner_is_a_valid_image, if: -> { banner.attached? }

  before_validation :normalize_tax_id

  scope :verified, -> { where(verified: true) }
  scope :not_on_vacation, -> { where(vacation_mode: false) }

  # Slug lookups for seller URLs (/s/:slug), including historical slugs so
  # renamed stores keep resolving (the controller 301s them to the new URL).
  def self.find_by_param(param)
    store = find_by(slug: param.to_s)
    return store if store

    slug = FriendlyId::Slug.where(slug: param.to_s, sluggable_type: name).order(id: :desc).first
    slug&.sluggable
  end

  # Published review counts per star rating, { 5 => n, …, 1 => n } in 5→1
  # order — one grouped query behind the reviews tab distribution bars.
  def rating_distribution
    counts = reviews.published.group(:rating).count
    (5).downto(1).index_with { |stars| counts.fetch(stars, 0) }
  end

  # Settings-form writer: consumes the remove_logo/remove_banner checkbox
  # flags (purging the matching attachments) so the controller stays skinny.
  def assign_settings(attributes)
    attrs = attributes.to_h.symbolize_keys
    remove_logo = attrs.delete(:remove_logo)
    remove_banner = attrs.delete(:remove_banner)
    assign_attributes(attrs)
    logo.purge if ActiveModel::Type::Boolean.new.cast(remove_logo)
    banner.purge if ActiveModel::Type::Boolean.new.cast(remove_banner)
    self
  end

  def display_name
    business? ? business_name.presence || name : name
  end

  def verified!
    update!(verified: true, verified_at: Time.current)
  end

  def slug_source
    name
  end

  # Renaming the store re-slugs it; :history keeps the old slug resolvable so
  # StoresController can 301 stale URLs to the canonical one.
  def should_generate_new_friendly_id?
    name_changed? || super
  end

  private

  def normalize_tax_id
    self.tax_id = tax_id.presence && tax_id.delete(" ").upcase
  end

  def logo_is_a_valid_image
    attachment_is_a_valid_image(logo, LOGO_MAX_SIZE, :logo)
  end

  def banner_is_a_valid_image
    attachment_is_a_valid_image(banner, BANNER_MAX_SIZE, :banner)
  end

  def attachment_is_a_valid_image(attachment, max_size, attribute)
    return unless attachment.blob

    unless IMAGE_CONTENT_TYPES.include?(attachment.blob.content_type)
      errors.add(attribute, :invalid_content_type)
    end
    errors.add(attribute, :too_large) if attachment.blob.byte_size > max_size
  end
end
