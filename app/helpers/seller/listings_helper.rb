module Seller
  module ListingsHelper
    # Active leaf categories (no children) grouped by their parent's
    # translated name — the grouped category select on the sell form.
    # Root-level leaves group under their own name.
    def grouped_category_options
      leaves = Category.active
                       .where.not(id: Category.where.not(parent_id: nil).select(:parent_id))
                       .includes(:parent).ordered
      leaves.group_by { |category| category.parent&.name || category.name }
            .transform_values do |categories|
        categories.map { |category| [ category.name, category.id ] }
      end
    end
  end
end
