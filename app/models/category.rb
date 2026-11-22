class Category < ApplicationRecord
  extend FriendlyId
  friendly_id :friendly_name, use: :slugged

  has_ancestry orphan_strategy: :destroy

  has_many :listings, dependent: :restrict_with_error, inverse_of: :category
  has_many :category_filters, dependent: :destroy, inverse_of: :category
  has_many :filter_definitions, through: :category_filters

  validates :slug, presence: true, uniqueness: true
  validate :names_present

  after_commit :bust_caches

  scope :roots_ordered, -> { roots.order(:position, :id) }

  def listings_for_delete?
    listings.exists? || children.exists?
  end

  def bust_caches
    MenuBuilder.bust!
    ListingSearch.bust_caches!
    Current.category_root_slugs = nil
  end
  scope :active, -> { where(active: true) }
  scope :menu_roots, -> { active.roots.where(show_in_menu: true).order(:position, :id) }

  # Root id => slug, cached alongside the taxonomy timestamp. Used by listing
  # cards to decide whether spec chips apply without loading the whole path.
  def self.root_slug_map
    return Current.category_root_slugs unless Current.category_root_slugs.nil?

    map = Rails.cache.fetch("category-root-slugs/v1", expires_in: 1.hour) do
      roots.pluck(:id, :slug).to_h
    end
    Current.category_root_slugs = map
    map
  end

  def self.find_by_path_slugs(slugs)
    slugs = Array(slugs).map(&:to_s).reject(&:blank?)
    return nil if slugs.empty?

    chain = where(slug: slugs).index_by(&:slug).then do |records|
      slugs.map { |slug| records[slug] }
    end
    return nil if chain.any?(&:nil?)

    category = chain.last
    return nil unless category.active?
    return nil unless chain.first.is_root?
    return nil unless chain.each_cons(2).all? { |parent, child| child.parent_id.to_s == parent.id.to_s }

    category
  end

  def path
    @path ||= super
  end

  def path_slugs
    @path_slugs ||= path.map(&:slug)
  end

  def subtree_ids
    @subtree_ids ||= super
  end

  def name(locale = I18n.locale)
    names[locale.to_s].presence ||
      names["es"].presence ||
      names["en"].presence
  end

  # Filters attached to this category and to every ancestor, de-duplicated and
  # ordered by position.
  def effective_filters
    CategoryFilter
      .where(category_id: [ id ] + ancestor_ids)
      .includes(filter_definition: :filter_options)
      .order(:position, :id)
      .filter_map { |category_filter| category_filter.filter_definition if category_filter.filter_definition.active? }
      .uniq(&:id)
      .sort_by { |filter| [ filter.position, filter.id ] }
  end

  def leaf?
    children.none?
  end

  def to_s
    name
  end

  private

  def friendly_name
    names["en"].presence || names["es"].presence || "category"
  end

  def names_present
    return if names.is_a?(Hash) && (names["en"].present? || names["es"].present?)

    errors.add(:names, :blank)
  end
end
