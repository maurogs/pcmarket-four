class FilterOption < ApplicationRecord
  include Translatable

  belongs_to :filter_definition

  translated_fields :label

  validates :value, presence: true, uniqueness: { scope: :filter_definition_id },
    format: { with: /\A[a-z0-9][a-z0-9._-]*\z/ }
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :numeric_value, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:position, :id) }
  # Featured first (shown above the "show more" cutoff), then by position.
  scope :featured_first, -> { order(featured: :desc, position: :asc, id: :asc) }

  delegate :key, to: :filter_definition
end
