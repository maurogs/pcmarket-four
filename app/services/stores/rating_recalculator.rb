module Stores
  # Recomputes a store's rating_avg (rounded to 2 decimals) and ratings_count
  # from its published reviews in a single aggregate query. Called from
  # Review's after_commit; safe to call directly (backfills, tests).
  class RatingRecalculator
    def self.call(store)
      return unless store.persisted?

      avg, count = store.reviews.published.pick(
        Arel.sql("COALESCE(ROUND(AVG(rating), 2), 0)"),
        Arel.sql("COUNT(*)")
      )
      store.update_columns(rating_avg: avg, ratings_count: count)
    end
  end
end
