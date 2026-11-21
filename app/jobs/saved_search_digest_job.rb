class SavedSearchDigestJob < ApplicationJob
  queue_as :default

  MAX_LISTINGS = 20

  def perform
    return unless Setting.enabled?("saved_search_alerts_enabled")

    SavedSearch.daily.notifying.includes(:user, :category).group_by(&:user).each do |user, searches|
      next if user.deleted? || !user.notify_by_email?("email_saved_search_alerts")

      entries = collect_entries(user, searches)
      next if entries.empty?

      SavedSearchMailer.digest(user, entries).deliver_later
      searches.each { |search| search.update_column(:last_notified_at, Time.current) if entries.any? { |entry| entry[:search] == search } }
    end
  end

  private

  def collect_entries(user, searches)
    entries = []
    remaining = MAX_LISTINGS

    searches.each do |search|
      break if remaining.zero?

      since = search.last_notified_at || 24.hours.ago
      listings = Listing.prefilter_for_saved_search(search)
                        .where("listings.published_at > ?", since)
                        .limit(remaining)
                        .to_a
                        .select { |listing| search.matches?(listing) }
      next if listings.empty?

      remaining -= listings.size
      entries << { search: search, listings: listings }
    end

    entries
  end
end
