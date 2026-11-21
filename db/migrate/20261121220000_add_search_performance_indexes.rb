class AddSearchPerformanceIndexes < ActiveRecord::Migration[8.1]
  def change
    add_index :listings, [ :status, :category_id, :published_at ],
              order: { published_at: :desc },
              name: "index_listings_search_category"

    add_index :listings, [ :status, :price_cents ],
              name: "index_listings_search_price"

    add_index :listings, [ :status, :favorites_count ],
              order: { favorites_count: :desc },
              name: "index_listings_search_popular"

    add_index :listings, [ :status, :store_id, :published_at ],
              order: { published_at: :desc },
              name: "index_listings_search_store"

    add_index :listings, [ :status, :region_id, :published_at ],
              order: { published_at: :desc },
              name: "index_listings_search_region"

    add_index :listings, [ :status, :published_at ],
              where: "status = 2 AND quantity > 0",
              order: { published_at: :desc },
              name: "index_listings_published_feed"
  end
end
