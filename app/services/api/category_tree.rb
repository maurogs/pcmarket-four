module Api
  # Builds the category tree payload with visible listing counts in a bounded
  # number of queries (one for categories, one grouped count).
  class CategoryTree
    def self.call
      categories = Category.active.order(:position, :id).to_a
      counts = Listing.visible.group(:category_id).count
      by_parent = categories.group_by { |category| parent_id_for(category) }

      build_nodes(by_parent, counts, nil)
    end

    def self.parent_id_for(category)
      ancestry = category.ancestry.to_s
      return nil if ancestry.blank?

      ancestry.split("/").last.to_i
    end

    def self.build_nodes(by_parent, counts, parent_id)
      by_parent.fetch(parent_id, []).map do |category|
        children = build_nodes(by_parent, counts, category.id)
        own_count = counts.fetch(category.id, 0)
        {
          id: category.id,
          slug: category.slug,
          name: category.name,
          path_slugs: category.path_slugs,
          icon: category.icon,
          position: category.position,
          listings_count: own_count + children.sum { |child| child[:listings_count] },
          children: children
        }
      end
    end
  end
end
