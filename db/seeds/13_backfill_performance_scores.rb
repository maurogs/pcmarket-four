# One-off backfill: give existing listings a performance_score so PC Finder
# works on them before they are next edited. update_column skips validations
# and the re-review callback, and the scorer is deterministic, so re-running
# the seeds just recomputes the same value.

Listing.where.not(specs: {}).find_each do |listing|
  listing.update_column(:performance_score, Listings::PerformanceScorer.call(listing))
end
