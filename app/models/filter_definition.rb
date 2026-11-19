# Admin-editable facet definitions: what "cpu_brand" or "gpu_memory" means,
# how it renders, and which values are valid for listings.
class FilterDefinition < ApplicationRecord
  include Translatable

  enum :input_type, {
    multi_select: 0, single_select: 1, range: 2, boolean: 3
  }, default: :multi_select

  has_many :filter_options, -> { ordered }, dependent: :destroy
  has_many :category_filters, dependent: :destroy
  has_many :categories, through: :category_filters

  translated_fields :label, :group

  validates :key, presence: true, uniqueness: true,
    format: { with: /\A[a-z][a-z0-9_]*\z/ }
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:position, :id) }
  scope :in_sidebar, -> { active.where(show_in_sidebar: true) }
  scope :in_listing_form, -> { active.where(show_in_listing_form: true) }
  scope :searchable, -> { active.where(searchable: true) }

  # Values that listings may store in `specs` for this filter.
  def option_values
    filter_options.active.pluck(:value)
  end

  # Renders as checkboxes/list of values, not a min/max range or a switch.
  def selection_like?
    multi_select? || single_select?
  end
end
