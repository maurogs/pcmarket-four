# Join between categories and filter definitions. Inheritance is resolved in
# Category#effective_filter_definitions (subcategories inherit their parents').
class CategoryFilter < ApplicationRecord
  belongs_to :category
  belongs_to :filter_definition

  validates :filter_definition_id, uniqueness: { scope: :category_id }
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
end
