class CategoryFilter < ApplicationRecord
  belongs_to :category, inverse_of: :category_filters
  belongs_to :filter_definition, inverse_of: :category_filters

  validates :filter_definition_id, uniqueness: { scope: :category_id }
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
end
