require "test_helper"

class MessagingAlertsJobsTest < ActiveJob::TestCase
  include ActionMailer::TestHelper

  setup do
    @buyer = users(:buyer)
    @seller = users(:seller)
    @listing = listings(:published_gpu)
  end

  test "expire offers job marks pending offers past their expiry" do
    offer = conversations(:buyer_seller_gpu).messages.create!(
      sender: @buyer, kind: :offer, offer_amount_cents: 40_000, body: "400"
    )
    offer.update_column(:offer_expires_at, 1.minute.ago)

    ExpireOffersJob.perform_now

    assert offer.reload.offer_expired?
  end

  test "followers are notified without an email when a store publishes" do
    assert_difference -> { @buyer.notifications.count }, 1 do
      NotifyFollowersJob.perform_now(@listing.id)
    end

    notification = @buyer.notifications.order(:id).last
    assert_equal "followed_store_listing", notification.kind
    assert_no_enqueued_emails { NotifyFollowersJob.perform_now(@listing.id) }
  end

  test "saved search alerts create a notification and email for matching buyers" do
    assert_difference -> { @buyer.notifications.count }, 1 do
      assert_enqueued_emails 1 do
        SavedSearchAlertJob.perform_now(@listing.id)
      end
    end

    notification = @buyer.notifications.order(:id).last
    assert_equal "saved_search_match", notification.kind
    assert saved_searches(:buyer_gpu_search).reload.last_notified_at.present?
  end

  test "saved search alerts exclude the listing owner" do
    owner_search = SavedSearch.create!(
      user: @seller, name: "Mi RTX", query: "RTX", category: categories(:graphics_cards),
      notify: true, frequency: :instant
    )

    SavedSearchAlertJob.perform_now(@listing.id)

    assert_not owner_search.reload.last_notified_at.present?
  end

  test "daily digest sends one email with new matches since last notification" do
    search = saved_searches(:buyer_gpu_search)
    search.update!(frequency: :daily, last_notified_at: 2.days.ago)
    @listing.update_column(:published_at, 1.hour.ago)

    assert_enqueued_emails 1 do
      SavedSearchDigestJob.perform_now
    end
    assert search.reload.last_notified_at.present?
  end

  test "price drop alerts notify and email favourite users" do
    Favorite.create!(user: @buyer, listing: @listing)

    assert_difference -> { @buyer.notifications.count }, 1 do
      assert_enqueued_emails 1 do
        PriceDropAlertJob.perform_now(@listing.id, 60_000)
      end
    end

    assert_equal "price_drop_favourite", @buyer.notifications.order(:id).last.kind
  end
end
