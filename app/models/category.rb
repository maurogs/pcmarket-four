class Category < ApplicationRecord
  extend FriendlyId
  friendly_id :friendly_name, use: :slugged

  has_ancestry orphan_strategy: :destroy

  has_many :listings, dependent: :restrict_with_error, inverse_of: :category
  has_many :category_filters, dependent: :destroy, inverse_of: :category
  has_many :filter_definitions, through: :category_filters

  validates :slug, presence: true, uniqueness: true
  validate :names_present

  scope :roots_ordered, -> { roots.order(:position, :id) }
  scope :active, -> { where(active: true) }

  def name(locale = I18n.locale)
    names[locale.to_s].presence ||
      names["es"].presence ||
      names["en"].presence
  end

  # Filters attached to this category and to every ancestor, de-duplicated and
  # ordered by position.
  def effective_filters
    CategoryFilter
      .where(category_id: path_ids)
      .includes(:filter_definition)
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
