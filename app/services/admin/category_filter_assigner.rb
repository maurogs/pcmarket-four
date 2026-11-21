module Admin
  # Ordered writes for category filter assignments. Keeps CategoryFilter rows
  # in sync with a submitted ordered list of filter definition ids.
  class CategoryFilterAssigner
    def initialize(category, filter_ids)
      @category = category
      @filter_ids = Array(filter_ids).map(&:to_i).reject(&:zero?).uniq
    end

    def call
      transaction do
        @category.category_filters.where.not(filter_definition_id: @filter_ids).destroy_all
        @filter_ids.each_with_index do |filter_id, index|
          @category.category_filters.find_or_initialize_by(filter_definition_id: filter_id)
                   .update!(position: index)
        end
      end
    end

    private

    def transaction(&block)
      Category.transaction(&block)
    end
  end
end
