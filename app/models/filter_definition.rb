class FilterDefinition < ApplicationRecord
  has_many :filter_options, -> { order(:position, :id) }, dependent: :destroy,
                           inverse_of: :filter_definition
  has_many :category_filters, dependent: :destroy, inverse_of: :filter_definition
  has_many :categories, through: :category_filters

  enum :input_type, { checkbox: 0, range: 1, select: 2, boolean: 3 }, prefix: :input

  validates :key, presence: true, uniqueness: true,
                  format: { with: /\A[a-z0-9_]+\z/ }
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  after_commit :bust_caches
  before_update :guard_key_immutability

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:position, :id) }

  def listing_usage_count
    Listing.where("specs ? :key", key: key).count
  end

  def bust_caches
    ListingSearch.bust_caches!
  end

  def name(locale = I18n.locale)
    names[locale.to_s].presence || names["es"].presence || names["en"].presence || key
  end

  def label(locale = I18n.locale)
    name(locale)
  end

  def to_s
    name
  end

  private

  def guard_key_immutability
    return unless key_changed? && key_was.present?

    errors.add(:key, :immutable)
    throw :abort
  end
end
