# The core sellable item. State machine (AASM):
#
#   draft → pending_review → published ⇄ paused
#                ↓               ↓  ↘
#             rejected          sold  archived (from most states)
#
# Editing the content (title/description/price/images/specs) of a published
# listing sends it back to pending_review unless the `listing_auto_approve`
# setting is on.
class Listing < ApplicationRecord
  include ActionView::Helpers::NumberHelper
  extend FriendlyId
  include AASM

  CURRENCY_CODE = /\A[A-Z]{3}\z/
  STATUSES = %w[draft pending_review published rejected paused sold archived].freeze

  # Server-side variants for every listing image (converted to webp).
  IMAGE_VARIANTS = {
    thumb: { resize_to_limit: [ 400, 400 ] },
    card: { resize_to_limit: [ 800, 800 ] },
    large: { resize_to_limit: [ 1600, 1600 ] }
  }.freeze
  IMAGE_FORMAT = "webp"
  ACCEPTED_IMAGE_TYPES = %w[image/jpeg image/png image/webp image/heic image/heif].freeze
  MAX_IMAGE_BYTES = 15.megabytes
  DEFAULT_MAX_IMAGES = 12

  # Attributes that make a published listing require a new review when edited.
  REVIEWABLE_FIELDS = %w[title description price_cents specs].freeze

  # Currency symbol map for display_price (amounts are stored in cents).
  CURRENCY_UNITS = { "EUR" => "€", "GBP" => "£", "USD" => "$" }.freeze

  # Saving the store (or (un)attaching images) bumps listing timestamps so
  # fragment caches on cards go stale.
  belongs_to :store, touch: true
  belongs_to :category
  belongs_to :country, optional: true
  belongs_to :reviewed_by, class_name: "User", optional: true

  has_many :listing_labels, dependent: :destroy
  has_many :product_labels, through: :listing_labels
  has_many :listing_seller_tags, dependent: :destroy
  has_many :seller_tags, through: :listing_seller_tags

  has_many_attached :images

  enum :condition, {
    new_sealed: 0, new_open_box: 1, used_like_new: 2,
    used_good: 3, used_fair: 4, for_parts: 5
  }, default: :used_good
  enum :shipping_method, { platform_label: 0, own_label: 1, pickup_only: 2 },
    default: :platform_label

  aasm column: :status do
    state :draft, initial: true
    state :pending_review, :published, :rejected, :paused, :sold, :archived

    event :submit do
      transitions from: [ :draft, :rejected ], to: :pending_review
    end

    event :approve, before: :set_published_timestamps do
      transitions from: :pending_review, to: :published
    end

    event :reject, before: :set_reviewed_timestamp do
      transitions from: :pending_review, to: :rejected
    end

    event :pause do
      transitions from: :published, to: :paused
    end

    event :resume, before: :set_published_timestamps do
      transitions from: :paused, to: :published
    end

    event :mark_sold, before: :set_sold_timestamp do
      transitions from: :published, to: :sold
    end

    event :archive do
      transitions to: :archived, from: [ :draft, :pending_review, :rejected,
        :published, :paused, :sold ]
    end

    # Fired automatically when a seller edits live content (see
    # #return_to_review_if_content_edited), never from the UI directly.
    event :return_to_review do
      transitions from: :published, to: :pending_review
    end
  end

  friendly_id :slug_source, use: [ :history ]

  # `searchable` is a trigger-maintained weighted tsvector (see the listings
  # migration). Queries go through the `listings_unaccented` config so the
  # query side folds accents exactly like the index does;
  # websearch_to_tsquery tolerates anything a user types.
  scope :matching, ->(query) {
    where("listings.searchable @@ websearch_to_tsquery('listings_unaccented', ?)", query)
  }

  # Weighted ts_rank over the same column — only used for sort: "relevance".
  def self.by_relevance(query)
    reorder(Arel.sql(
      "ts_rank(listings.searchable, websearch_to_tsquery('listings_unaccented', " \
      "#{connection.quote(query)})) DESC, listings.id DESC"
    ))
  end

  validates :title, presence: true, length: { in: 4..120 }
  validates :description, length: { maximum: 20_000 }
  validates :price_cents, presence: true,
    numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :original_price_cents, numericality: { only_integer: true, greater_than: 0 },
    allow_nil: true
  validates :currency, presence: true, format: { with: CURRENCY_CODE }
  validates :quantity, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :slug, presence: true, uniqueness: true, allow_nil: true
  validates :views_count, :favorites_count, :watchers_count,
    numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :shipping_price_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :ships_within_days,
    numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: 30 }
  validates :weight_grams, numericality: { greater_than: 0 }, allow_nil: true
  validates :province, inclusion: { in: ->(_) { SpanishProvince.codes } },
    allow_blank: true, if: :spain?
  validate :original_price_above_price
  validate :specs_are_valid
  validate :images_are_valid

  before_validation :normalize_specs
  before_save :snapshot_review_context
  before_save :assign_performance_score, if: :will_save_change_to_specs?
  after_save :return_to_review_if_content_edited
  after_save :queue_counter_refreshes, if: :category_or_status_changed?
  after_destroy :queue_counter_refreshes

  scope :published, -> { where(status: "published") }
  scope :visible, -> { published.where(store: Store.not_on_vacation) }
  scope :in_category, ->(category) { where(category_id: category.self_and_descendant_ids) }
  scope :with_specs, ->(filters) { where(specs_condition(filters)) }
  scope :price_between, ->(min, max) {
    where(min.present? ? [ "price_cents >= ?", min.to_i ] : nil)
      .where(max.present? ? [ "price_cents <= ?", max.to_i ] : nil)
  }
  scope :condition_in, ->(values) { where(condition: values) }
  scope :with_labels, ->(slugs) {
    where(id: ListingLabel.joins(:product_label).where(product_labels: { slug: slugs }).select(:listing_id))
  }
  scope :with_seller_tags, ->(slugs) {
    where(id: ListingSellerTag.joins(:seller_tag).where(seller_tags: { slug: slugs }).select(:listing_id))
  }
  scope :featured_now, -> { where("listings.featured_until > ?", Time.current) }
  scope :for_store, ->(store) { where(store: store) }
  scope :newest, -> { order(published_at: :desc, id: :desc) }
  scope :price_asc, -> { order(price_cents: :asc, id: :asc) }
  scope :price_desc, -> { order(price_cents: :desc, id: :desc) }
  scope :most_watched, -> { order(watchers_count: :desc, published_at: :desc, id: :desc) }
  # Featured (paid highlight active) first, then recency.
  scope :best_match, -> {
    order(Arel.sql(
      "CASE WHEN listings.featured_until > NOW() THEN 0 ELSE 1 END, " \
      "COALESCE(listings.published_at, listings.created_at) DESC, listings.id DESC"
    ))
  }

  # Search / browse eager-loads: store (+ logo blob), badge labels and image
  # blobs without N+1s.
  scope :with_includes, -> {
    includes(store: { logo_attachment: :blob }, product_labels: [], images_attachments: :blob)
  }

  # Slug lookups for canonical URLs, including historical slugs.
  def self.find_by_param(param)
    listing = find_by(slug: param.to_s)
    return listing if listing

    slug = FriendlyId::Slug.where(slug: param.to_s, sluggable_type: name).order(id: :desc).first
    slug&.sluggable
  end

  RELATED_TTL = 10.minutes
  ESTIMATED_TRANSIT_DAYS = 3

  # Listings in the same category subtree, priced near `listing` (±50%).
  # Candidate ids are cached for RELATED_TTL; the relation itself reloads
  # associations so cards render without N+1s.
  def self.similar_to(listing, limit: 8)
    ids = Rails.cache.fetch("listings/similar_to/#{listing.id}", expires_in: RELATED_TTL) do
      center = listing.price_cents
      visible.in_category(listing.category).where.not(id: listing.id)
        .price_between((center * 0.5).floor, (center * 1.5).ceil)
        .best_match.limit(limit).pluck(:id)
    end
    where(id: ids).with_includes.reorder(id: :asc)
  end

  # The seller's other visible listings, ids cached the same way.
  def self.more_from_store(listing, limit: 8)
    ids = Rails.cache.fetch("listings/more_from_store/#{listing.store_id}-#{listing.id}", expires_in: RELATED_TTL) do
      visible.for_store(listing.store).where.not(id: listing.id)
        .best_match.limit(limit).pluck(:id)
    end
    where(id: ids).with_includes.reorder(id: :asc)
  end

  # @param filters [Hash] { "filter_key" => ["option_value", …] } — values are
  #   OR-ed within a key, keys are AND-ed (jsonb containment @> on specs).
  def self.specs_condition(filters)
    groups = filters.to_h.filter_map do |key, values|
      containments = Array(values).map(&:to_s).reject(&:empty?).map do |value|
        json = connection.quote({ key => [ value ] }.to_json)
        Arel::Nodes::SqlLiteral.new("listings.specs @> #{json}::jsonb")
      end
      next if containments.empty?

      grouped = containments.map { |node| Arel::Nodes::Grouping.new(node) }
      grouped.reduce { |memo, node| Arel::Nodes::Or.new([ memo, node ]) }
    end
    return nil if groups.empty?

    Arel::Nodes::And.new(groups.map { |node| Arel::Nodes::Grouping.new(node) })
  end

  def featured_now?
    featured_until.present? && featured_until > Time.current
  end

  # Publicly visible: approved and the seller is not on vacation.
  def visible_to_public?
    published? && !store.vacation_mode
  end

  # Owners and admins may preview drafts / pending / paused listings.
  def viewable_by?(user)
    return true if visible_to_public?
    return false if user.nil?

    user.admin? || user.id == store.user_id
  end

  # Earliest delivery: preparation days only; latest adds estimated transit.
  def estimated_arrival_from
    ships_within_days.days.from_now.to_date
  end

  def estimated_arrival_to
    (ships_within_days + ESTIMATED_TRANSIT_DAYS).days.from_now.to_date
  end

  def spain?
    country&.code == "ES"
  end

  # Integer percent saved vs original_price_cents, or nil when there is no
  # comparison price.
  def discount_percent
    return if original_price_cents.blank? || original_price_cents <= price_cents

    ((original_price_cents - price_cents).fdiv(original_price_cents) * 100).round
  end

  # Locale-formatted amount with the listing currency's symbol.
  def display_price
    number_to_currency(price_cents / 100.0, unit: currency_unit)
  end

  # Struck-through comparison price, or nil when there is none.
  def display_original_price
    return if original_price_cents.blank?

    number_to_currency(original_price_cents / 100.0, unit: currency_unit)
  end

  def status_label
    I18n.t("activerecord.attributes.listing.statuses.#{status}", default: status.humanize)
  end

  def condition_label
    I18n.t("activerecord.attributes.listing.condition.#{condition}")
  end

  # Human labels for the stored specs, for display and search indexing:
  # { "gpu_chipset" => ["NVIDIA"] }.
  def spec_labels
    FilterOption
      .includes(:filter_definition)
      .where(filter_definition: FilterDefinition.where(key: specs.keys))
      .where(value: specs.values.flatten.map(&:to_s))
      .each_with_object({}) do |option, labels|
        (labels[option.filter_definition.key] ||= []) << option.label
      end
  end

  # Slug base is the English-safe title; FriendlyId adds the id on conflicts.
  def slug_source
    title
  end

  private

  def currency_unit
    CURRENCY_UNITS.fetch(currency) { "#{currency} " }
  end

  # Recompute the PC Finder benchmark score whenever specs change.
  def assign_performance_score
    self.performance_score = Listings::PerformanceScorer.call(self)
  end

  def original_price_above_price
    return if original_price_cents.blank? || original_price_cents > price_cents

    errors.add(:original_price_cents, :must_exceed_price)
  end

  # Specs are stored as { key => [option_value, …] } with string values
  # (booleans become "true"/"false") so jsonb containment stays uniform.
  def normalize_specs
    self.specs = parse_json_object(specs)
    return if specs.blank?

    self.specs = specs.each_with_object({}) do |(key, value), normalized|
      key = key.to_s
      next if key.blank? || value.nil? || value == [] || value == ""

      values = Array(value).map { |v| v.is_a?(String) ? v : v.to_s }.uniq.sort
      normalized[key] = values unless values.empty?
    end
  end

  def parse_json_object(value)
    return value unless value.is_a?(String)

    parsed = JSON.parse(value)
    parsed.is_a?(Hash) ? parsed : {}
  rescue JSON::ParserError
    {}
  end

  def specs_are_valid
    return if specs.blank?

    definitions = FilterDefinition.active.where(key: specs.keys.map(&:to_s)).index_by(&:key)

    specs.each do |key, values|
      definition = definitions[key]
      if definition.nil?
        errors.add(:specs, :unknown_filter_key, key: key)
        next
      end

      allowed = definition.boolean? ? %w[true false] : definition.option_values
      invalid = values - allowed
      errors.add(:specs, :unknown_filter_value, key: key, value: invalid.join(", ")) if invalid.any?
    end
  end

  def images_are_valid
    attachments = images.attachments
    return if attachments.empty?

    max = AppSettings.get("max_images_per_listing", DEFAULT_MAX_IMAGES).to_i
    errors.add(:images, :too_many_images, max: max) if attachments.size > max

    attachments.each do |attachment|
      blob = attachment.blob
      next if blob.nil?

      unless ACCEPTED_IMAGE_TYPES.include?(blob.content_type)
        errors.add(:images, :unsupported_content_type, content_type: blob.content_type)
      end
      if blob.byte_size > MAX_IMAGE_BYTES
        errors.add(:images, :too_large_image, max_megabytes: MAX_IMAGE_BYTES / 1.megabyte)
      end
    end
  end

  # --- Re-review on edit -----------------------------------------------------

  def snapshot_review_context
    return unless persisted? && status == "published"

    @content_edit_pending = REVIEWABLE_FIELDS.any? { |field| will_save_change_to_attribute?(field) }
    @images_before_edit = image_blob_ids
  end

  def return_to_review_if_content_edited
    return unless @images_before_edit # only set for published listings being saved
    return unless status == "published"
    return if AppSettings.enabled?("listing_auto_approve")

    images_changed = image_blob_ids != @images_before_edit
    return_to_review! if @content_edit_pending || images_changed
  end

  def image_blob_ids
    ActiveStorage::Attachment
      .where(record_type: "Listing", record_id: id, name: "images")
      .order(:id).pluck(:blob_id)
  end

  # --- State machine timestamps ----------------------------------------------

  def set_published_timestamps
    self.published_at ||= Time.current
    self.reviewed_at = Time.current
  end

  def set_sold_timestamp
    self.sold_at = Time.current
  end

  def set_reviewed_timestamp
    self.reviewed_at = Time.current
  end

  # --- Counter maintenance ---------------------------------------------------

  def category_or_status_changed?
    saved_changes.key?("category_id") || saved_changes.key?("status")
  end

  def queue_counter_refreshes
    Categories::RefreshListingsCountJob.perform_later(category_id)
    old_category_id = saved_changes["category_id"]&.first
    Categories::RefreshListingsCountJob.perform_later(old_category_id) if old_category_id
    Stores::RefreshCountersJob.perform_later(store_id)
  end
end
