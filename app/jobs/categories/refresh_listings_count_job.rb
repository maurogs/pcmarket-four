module Categories
  class RefreshListingsCountJob < ApplicationJob
    queue_as :default

    # Ids (not records) so a destroyed category never deserializes.
    def perform(category_id)
      category = Category.find_by(id: category_id)
      return if category.nil?

      RefreshListingsCount.call(category)
    end
  end
end
