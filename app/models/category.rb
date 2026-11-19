class Category < ApplicationRecord
  include Translatable
  extend FriendlyId

  # Marketplace flavours drive merchandising, not URL structure.
  enum :kind, {
    full_system: 0, component: 1, peripheral: 2, mobile: 3,
    gaming_system: 4, accessory: 5, software: 6
  }, default: :full_system

  belongs_to :parent, class_name: "Category", optional: true
  has_many :children, -> { order(:position, :id) }, class_name: "Category",
    foreign_key: :parent_id, dependent: :destroy
  has_many :listings, dependent: :restrict_with_exception
  has_many :category_filters, dependent: :destroy
  has_many :filter_definitions, through: :category_filters
  has_one_attached :image

  translated_fields :name, :description, :seo_title, :seo_description

  validates :slug, presence: true, uniqueness: true,
    format: { with: /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/ }, allow_nil: true
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :listings_count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :name_translations_present
  validate :parent_is_not_descendant

  # Globally unique slugs generated from the English name. Seeds set the slug
  # explicitly so re-running them never regenerates it.
  friendly_id :slug_source, use: :slugged

  before_validation :assign_position, on: :create

  scope :active, -> { where(active: true) }
  scope :roots, -> { where(parent_id: nil) }
  scope :ordered, -> { order(:position, :id) }
  scope :for_kind, ->(kind) { where(kind: kind) }

  # Tree helpers. Each recursive walk is one query.
  def self_and_descendant_ids
    chain_ids_sql(subtree: true)
  end

  def descendant_ids
    self_and_descendant_ids - [ id ]
  end

  def self_and_ancestor_ids
    chain_ids_sql(subtree: false)
  end

  def ancestor_ids
    self_and_ancestor_ids - [ id ]
  end

  def depth
    ancestor_ids.size
  end

  # Filter definitions available in this category, inherited from ancestors
  # (nearest category first, its own definitions win over inherited ones).
  def effective_filter_definitions
    chain = Category.where(id: self_and_ancestor_ids).sort_by { |c| c.depth }
      .reverse
    seen = {}
    chain.each do |category|
      category.category_filters.includes(:filter_definition).each do |category_filter|
        definition = category_filter.filter_definition
        next unless definition.active?
        seen[definition.id] ||= [ category_filter.position, definition ]
      end
    end
    seen.values.sort_by { |position, definition| [ definition.group, position, definition.id ] }
      .map(&:last)
  end

  # Slug lookups tolerate both active browsing and admin/legacy rows.
  def self.find_by_param(param)
    find_by(slug: param.to_s)
  end

  # Counter cache helper — used by Categories::RefreshListingsCount only.
  def refresh_listings_count!
    update_column(:listings_count,
      Listing.in_category(self).published.count)
  end

  # FriendlyId base — never rename, it feeds the canonical slug.
  def slug_source
    name_translations.to_h["en"]
  end

  private

  def name_translations_present
    return if name_translations.is_a?(Hash) && name_translations["en"].present?

    errors.add(:name_translations, :blank)
  end

  def assign_position
    return if position && position > 0

    self.position = (Category.where(parent_id: parent_id).maximum(:position) || 0) + 1
  end

  def parent_is_not_descendant
    return unless parent_id.present? && persisted? && descendant_ids.include?(parent_id)

    errors.add(:parent_id, :invalid)
  end

  # One recursive CTE walks the whole chain in either direction.
  def chain_ids_sql(subtree:)
    join = subtree ? "c.parent_id = s.id" : "s.parent_id = c.id"
    Category.connection.select_values(
      Category.sanitize_sql_array([ <<~SQL, id: id ])
        WITH RECURSIVE s AS (
          SELECT c.id, c.parent_id FROM categories c WHERE c.id = :id
          UNION ALL
          SELECT c.id, c.parent_id
          FROM categories c JOIN s ON #{join}
        )
        SELECT id FROM s
      SQL
    )
  end
end
