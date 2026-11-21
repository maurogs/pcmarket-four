class Listing < ApplicationRecord
  extend FriendlyId

  MAX_IMAGE_BYTES = 10.megabytes
  IMAGE_CONTENT_TYPES = %w[image/jpeg image/png image/webp].freeze
  MIN_TITLE_LENGTH = 10
  MAX_TITLE_LENGTH = 120
  MIN_DESCRIPTION_LENGTH = 30
  MAX_PRICE_CENTS = 100_000_000

  REVIEW_TRIGGER_ATTRIBUTES = %w[title category_id].freeze
  ACTIVE_STATUSES = %i[draft pending_review published paused rejected].freeze

  LABELS = %w[value mid_range pro_gamer rare featured deal free_shipping].freeze
  TAGS = %w[minimalist rgb white black anime retro compact cozy glass luxe noctua
            sci_fi space steampunk wood whiteout blackout sakura superhero rainbow].freeze

  friendly_id :slug_candidates, use: [ :slugged, :history ]

  belongs_to :user, inverse_of: :listings
  belongs_to :store, optional: true, counter_cache: :listings_count, inverse_of: :listings
  belongs_to :category, counter_cache: :listings_count, inverse_of: :listings
  belongs_to :region, optional: true, inverse_of: :listings
  belongs_to :country, foreign_key: :country_code, primary_key: :code, inverse_of: :listings,
                       optional: true
  belongs_to :reviewer, class_name: "User", foreign_key: :reviewed_by_id, optional: true,
                        inverse_of: false

  has_many_attached :images

  has_many :favorites, dependent: :destroy, inverse_of: :listing
  has_many :favorited_by_users, through: :favorites, source: :user
  has_many :cart_items, dependent: :destroy, inverse_of: :listing
  has_many :order_items, dependent: :restrict_with_error, inverse_of: :listing
  has_many :conversations, dependent: :nullify, inverse_of: :listing

  enum :condition, {
    new_sealed: 0,
    new_open_box: 1,
    used_like_new: 2,
    used_good: 3,
    used_fair: 4,
    for_parts: 5
  }
  enum :status, {
    draft: 0,
    pending_review: 1,
    published: 2,
    rejected: 3,
    paused: 4,
    sold: 5,
    archived: 6
  }

  pg_search_scope :search_text,
                  against: { title: "A", brand: "B", description: "C" },
                  using: {
                    tsearch: { prefix: true, dictionary: "simple" },
                    trigram: { threshold: 0.2 }
                  },
                  ignoring: :accents

  validates :title, presence: true,
                    length: { minimum: MIN_TITLE_LENGTH, maximum: MAX_TITLE_LENGTH }
  validates :description, presence: true, length: { minimum: MIN_DESCRIPTION_LENGTH }
  validates :price_cents, presence: true,
                          numericality: { only_integer: true, greater_than: 0,
                                          less_than_or_equal_to: MAX_PRICE_CENTS }
  validates :quantity, numericality: { only_integer: true, greater_than: 0 }
  validates :ships_within_days, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :shipping_price_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  attr_accessor :media_changed

  before_validation :assign_store, on: :create

  validate :original_price_must_exceed_price
  validate :postal_code_format
  validate :country_must_be_enabled
  validate :category_must_be_leaf
  validate :images_within_limits
  validate :within_active_listing_quota, on: :create

  scope :visible, lambda {
    published
      .where(quantity: 1..)
      .joins(:user, :country)
      .where(users: { status: User.statuses[:active], deleted_at: nil })
      .where(countries: { enabled: true })
  }
  # Publicly browsable listings: published items plus sold items that stay
  # online for SEO and price history. Used by store pages, which expose sold
  # items behind an explicit toggle.
  scope :storefront, lambda {
    where(status: [ statuses[:published], statuses[:sold] ])
      .where(quantity: 1..)
      .joins(:user, :country)
      .where(users: { status: User.statuses[:active], deleted_at: nil })
      .where(countries: { enabled: true })
  }
  scope :featured, -> { where("listings.featured_until > ?", Time.current) }
  scope :recent, -> { order(published_at: :desc, created_at: :desc) }
  scope :in_category, ->(category) { where(category_id: category.subtree_ids) }
  scope :on_sale, lambda {
    where("listings.original_price_cents IS NOT NULL AND listings.original_price_cents > listings.price_cents")
  }
  scope :recently_sold, lambda {
    sold
      .joins(:user, :country)
      .where(users: { status: User.statuses[:active], deleted_at: nil })
      .where(countries: { enabled: true })
      .order(published_at: :desc, updated_at: :desc)
  }

  def submit_for_review!
    return false unless draft? || rejected?

    if Setting.enabled?("listings_require_approval")
      update!(status: :pending_review, rejection_reason: nil)
    else
      publish!
    end
    true
  end

  def publish!
    update!(
      status: :published,
      published_at: published_at || Time.current,
      rejection_reason: nil
    )
    true
  end

  def approve!(reviewer)
    return false unless pending_review?

    update!(
      status: :published,
      reviewed_at: Time.current,
      reviewed_by_id: reviewer.id,
      published_at: published_at || Time.current,
      rejection_reason: nil
    )
    true
  end

  def reject!(reviewer, reason)
    return false unless pending_review?

    update!(
      status: :rejected,
      reviewed_at: Time.current,
      reviewed_by_id: reviewer.id,
      rejection_reason: reason
    )
    true
  end

  def pause!
    return false unless published?

    update!(status: :paused)
    true
  end

  def resume!
    return false unless paused?

    update!(status: :published, published_at: published_at || Time.current)
    true
  end

  def mark_sold!
    return false unless published? || paused?

    update!(status: :sold)
    true
  end

  # Price/quantity/shipping/description edits keep a published listing live.
  # Title, category and image changes need a moderator to look at it again.
  def requires_re_review?
    return false unless Setting.enabled?("listings_require_approval")
    return false unless published?

    (saved_changes.keys & REVIEW_TRIGGER_ATTRIBUTES).any? || !!media_changed
  end

  def send_back_for_review!
    update_columns(
      status: self.class.statuses[:pending_review],
      rejection_reason: nil,
      updated_at: Time.current
    )
    self.status = "pending_review"
    true
  end

  def ordered_images
    images.includes(:blob).to_a.sort_by { |image| [ image.blob.metadata["position"].to_i, image.id.to_i ] }
  end

  def featured?
    featured_until.present? && featured_until > Time.current
  end

  def visible?
    published? && quantity.to_i.positive? && user&.active_account? &&
      Country.enabled.exists?(code: country_code)
  end

  def price
    price_cents.to_i / 100.0
  end

  def price=(value)
    self.price_cents = self.class.parse_price_cents(value)
  end

  def original_price=(value)
    self.original_price_cents = self.class.parse_price_cents(value)
  end

  def shipping_price=(value)
    self.shipping_price_cents = self.class.parse_price_cents(value) || 0
  end

  # Accepts "1.299,50", "1299.50", "1299" and "€ 1.299" and returns cents.
  def self.parse_price_cents(value)
    return nil if value.nil?
    return value.to_i if value.is_a?(Numeric)

    raw = value.to_s.strip.delete("€").delete(" ").delete("\u00A0")
    return nil if raw.empty?

    raw = if raw.include?(",")
      raw.delete(".").tr(",", ".")
    else
      raw.delete(",")
    end
    return nil unless raw.match?(/\A\d+(\.\d{1,2})?\z/)

    (BigDecimal(raw) * 100).round
  rescue ArgumentError
    nil
  end

  def viewable_by?(viewer)
    return true if sold?
    return true if visible?

    viewer.present? && (viewer.id == user_id || viewer.staff?)
  end

  def editable_by?(viewer)
    viewer.present? && (viewer.id == user_id || viewer.staff?)
  end

  def sold_out?
    sold? || quantity.to_i.zero?
  end

  def location
    [ city, region&.name ].compact_blank.uniq.join(", ")
  end

  def estimated_delivery_window
    return nil unless shipping_available?

    start_date = self.class.add_business_days(Date.current, ships_within_days.to_i + 2)
    end_date = self.class.add_business_days(start_date, 2)
    start_date..end_date
  end

  def self.add_business_days(date, days)
    date = date.to_date
    remaining = days.to_i
    while remaining.positive?
      date += 1
      remaining -= 1 unless date.saturday? || date.sunday?
    end
    date
  end

  def self.seller_board(user, status: "all", query: nil)
    scope = user.listings.includes(:category, :store, images_attachments: :blob)
    scope = scope.where(status: status) if statuses.key?(status)
    if query.present?
      pattern = "%#{sanitize_sql_like(query.to_s.strip)}%"
      scope = scope.where("listings.title ILIKE :q OR listings.brand ILIKE :q", q: pattern)
    end
    scope.order(updated_at: :desc)
  end

  def self.similar_to(listing, limit: 8)
    visible
      .where(category_id: listing.category.subtree_ids)
      .where.not(id: listing.id)
      .order(Arel.sql(sanitize_sql_array([ "ABS(listings.price_cents - ?)", listing.price_cents ])))
      .limit(limit)
  end

  # Increments the view counter with a single UPDATE. The caller decides
  # whether the current visitor counts as a view.
  def self.register_view!(id)
    where(id: id).update_all("views_count = views_count + 1, updated_at = updated_at")
  end

  private

  def slug_candidates
    [ title, "#{title}-#{SecureRandom.hex(3)}" ]
  end

  def original_price_must_exceed_price
    return if original_price_cents.blank? || price_cents.blank?

    return if original_price_cents > price_cents

    errors.add(:original_price_cents, :greater_than_price)
  end

  def postal_code_format
    return if postal_code.blank?
    return unless country_code == "ES"
    return if postal_code.match?(/\A\d{5}\z/)

    errors.add(:postal_code, :invalid)
  end

  def country_must_be_enabled
    return if country_code.blank?
    return if Country.enabled.exists?(code: country_code)

    errors.add(:country_code, :not_enabled)
  end

  def category_must_be_leaf
    return if category.blank?
    return unless category.children.exists?

    errors.add(:category, :not_a_leaf)
  end

  def assign_store
    return if store.present? || user.blank?

    self.store = user.ensure_store!
  end

  def within_active_listing_quota
    return if user.blank?

    max = Setting.get("max_active_listings_per_user", 50).to_i
    return unless max.positive?
    return if user.listings.where(status: ACTIVE_STATUSES).count < max

    errors.add(:base, :quota_exceeded, max: max)
  end

  def images_within_limits
    return unless images.attached?

    images.each do |image|
      errors.add(:images, :invalid_format) unless IMAGE_CONTENT_TYPES.include?(image.content_type)
      errors.add(:images, :too_large) if image.byte_size.to_i > MAX_IMAGE_BYTES
    end

    max_images = Setting.get("max_images_per_listing", 12).to_i
    errors.add(:images, :too_many, count: max_images) if images.size > max_images
  end
end
