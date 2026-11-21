class SavedSearch < ApplicationRecord
  belongs_to :user, inverse_of: :saved_searches
  belongs_to :category, optional: true, inverse_of: false

  enum :frequency, { instant: 0, daily: 1 }

  validates :name, presence: true
  validate :price_range_is_ordered

  scope :notifying, -> { where(notify: true) }

  # Builds a saved search from a ListingSearch result. The normalised search
  # parameters are stored under a reserved `_search` key so alert jobs replay
  # exactly the same query.
  def self.build_from(user:, search:, name: nil)
    normalized = search.normalized_params
    new(
      user: user,
      name: name.presence || default_name_for(search),
      query: normalized[:q],
      category_id: normalized[:category_id],
      min_price_cents: normalized[:min_price_cents],
      max_price_cents: normalized[:max_price_cents],
      filters: normalized[:specs].merge("_search" => search.query_params.deep_stringify_keys),
      notify: true
    )
  end

  def self.default_name_for(search)
    normalized = search.normalized_params
    parts = [ normalized[:q] ]
    if normalized[:category_id].present?
      parts << Category.find_by(id: normalized[:category_id])&.name
    end
    parts.compact_blank.join(" · ").presence || I18n.t("saved_searches.default_name")
  end

  # SQL pre-filter: category subtree (the saved category is an ancestor of the
  # listing category), price and country. matches? then checks query and specs.
  def self.prefilter_for(listing)
    path_ids = listing.category&.path_ids || []
    scope = notifying.where.not(user_id: listing.user_id)
    scope = scope.where("min_price_cents IS NULL OR min_price_cents <= ?", listing.price_cents)
    scope = scope.where("max_price_cents IS NULL OR max_price_cents >= ?", listing.price_cents)
    scope = scope.where("country_code IS NULL OR country_code = ?", listing.country_code)
    if path_ids.any?
      scope = scope.where("category_id IS NULL OR category_id IN (?)", path_ids)
    end
    scope
  end

  def spec_filters
    filters.reject { |key, _value| key.to_s.start_with?("_") }
  end

  def matches?(listing)
    return false if listing.blank?
    return false unless Listing.visible.where(id: listing.id).exists?
    return false if user_id == listing.user_id
    return false if country_code.present? && listing.country_code != country_code
    return false if min_price_cents.present? && listing.price_cents < min_price_cents
    return false if max_price_cents.present? && listing.price_cents > max_price_cents
    return false if category_id.present? && !category.subtree_ids.include?(listing.category_id)
    return false if query.present? && !query_matches?(listing)

    spec_filters.all? { |key, value| filter_matches?(listing, key, value) }
  end

  def result_path
    segments = filters["_search"].is_a?(Hash) ? filters["_search"].dup : {}
    base = category ? "/c/#{category.path_slugs.join('/')}" : "/search"
    query = segments.except("category_id", "page", "sort").to_query
    query.present? ? "#{base}?#{query}" : base
  end

  private

  def query_matches?(listing)
    term = query.to_s.strip.downcase
    return true if term.blank?

    [ listing.title, listing.brand, listing.description ].compact.any? do |text|
      text.to_s.downcase.include?(term)
    end
  end

  def filter_matches?(listing, key, expected)
    wanted = Array.wrap(expected).map(&:to_s).reject(&:blank?)
    return true if wanted.empty?

    actual = Array.wrap(listing.specs[key]).map(&:to_s)
    (actual & wanted).any?
  end

  def price_range_is_ordered
    return if min_price_cents.blank? || max_price_cents.blank?
    return if min_price_cents <= max_price_cents

    errors.add(:max_price_cents, :greater_than_or_equal_to_min)
  end
end
