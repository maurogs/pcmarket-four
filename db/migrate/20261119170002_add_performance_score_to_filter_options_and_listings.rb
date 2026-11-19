class AddPerformanceScoreToFilterOptionsAndListings < ActiveRecord::Migration[8.1]
  def change
    # Benchmark score (0–100) per machine value, e.g. "rtx_4070" => 80.
    add_column :filter_options, :performance_score, :integer

    # Cached score for a listing, computed by Listings::PerformanceScorer.
    add_column :listings, :performance_score, :integer
    add_index :listings, [ :status, :performance_score ],
      name: "idx_listings_status_performance_score", where: "status = 'published'"
  end
end
