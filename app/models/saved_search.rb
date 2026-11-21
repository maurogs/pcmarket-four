class SavedSearch < ApplicationRecord
  belongs_to :user, inverse_of: :saved_searches
  belongs_to :category, optional: true, inverse_of: false

  validates :name, presence: true
  validate :price_range_is_ordered

  # Builds a saved search from a ListingSearch result. The normalised search
  # parameters are stored under a reserved `_search` key so future alert jobs
  # can replay exactly the same query.
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

  def spec_filters
    filters.reject { |key, _value| key.to_s.start_with?("_") }
  end

  def matches?(listing)
    return false if listing.blank?
    return false unless Listing.visible.where(id: listing.id).exists?
    return false if country_code.present? && listing.country_code != country_code
    return false if min_price_cents.present? && listing.price_cents < min_price_cents
    return false if max_price_cents.present? && listing.price_cents > max_price_cents
    return false if category_id.present? && !category.subtree_ids.include?(listing.category_id)
    return false if query.present? && !query_matches?(listing)

    spec_filters.all? { |key, value| filter_matches?(listing, key, value) }
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
