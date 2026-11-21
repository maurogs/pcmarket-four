class SavedSearch < ApplicationRecord
  belongs_to :user, inverse_of: :saved_searches
  belongs_to :category, optional: true, inverse_of: false

  validates :name, presence: true
  validate :price_range_is_ordered

  def matches?(listing)
    return false if listing.blank?
    return false unless Listing.visible.where(id: listing.id).exists?
    return false if country_code.present? && listing.country_code != country_code
    return false if min_price_cents.present? && listing.price_cents < min_price_cents
    return false if max_price_cents.present? && listing.price_cents > max_price_cents
    return false if category_id.present? && !category.subtree_ids.include?(listing.category_id)
    return false if query.present? && !query_matches?(listing)

    filters.all? { |key, value| filter_matches?(listing, key, value) }
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
