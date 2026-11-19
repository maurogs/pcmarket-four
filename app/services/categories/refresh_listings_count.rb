module Categories
  # Recomputes `listings_count` (published listings incl. descendants) for a
  # category and all its ancestors — a change in a leaf moves every counter
  # up to the root.
  class RefreshListingsCount
    def self.call(category)
      Category.where(id: category.self_and_ancestor_ids).find_each(&:refresh_listings_count!)
    end
  end
end
