require "test_helper"

class AdminModerationTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup { sign_in users(:admin) }

  test "approving a listing publishes it, notifies the seller and audits" do
    listing = listings(:pending_review_gpu)

    assert_difference -> { listing.user.notifications.count }, 1 do
      assert_enqueued_with(job: ActionMailer::MailDeliveryJob) do
        post admin_listing_approval_path(listing, locale: :es)
      end
    end

    assert_redirected_to admin_moderation_queue_path(locale: :es)
    assert_equal "published", listing.reload.status
    assert_equal users(:admin).id, listing.reviewed_by_id
    assert_equal "listing_approved", listing.user.notifications.last.kind

    audit = AdminAuditLog.where(action: "listing.approved").order(:created_at).last
    assert_equal users(:admin).id, audit.admin_id
    assert_equal listing, audit.auditable
    assert_equal "127.0.0.1", audit.ip
  end

  test "rejecting a listing stores the translated reason and emails the seller" do
    listing = listings(:pending_review_gpu)

    assert_enqueued_with(job: ActionMailer::MailDeliveryJob) do
      post admin_listing_rejection_path(listing, locale: :es),
           params: { reason: "prohibited" }
    end

    assert_redirected_to admin_moderation_queue_path(locale: :es)
    assert_equal "rejected", listing.reload.status
    assert_equal I18n.t("admin.moderation.reasons.prohibited", locale: :es), listing.rejection_reason
    assert_equal "listing_rejected", listing.user.notifications.last.kind

    perform_enqueued_jobs
    email = ActionMailer::Base.deliveries.last
    assert_equal [ listing.user.email ], email.to
    assert_match listing.title, email.subject
  end

  test "rejection without a reason is refused" do
    listing = listings(:pending_review_gpu)

    post admin_listing_rejection_path(listing, locale: :es)

    assert_redirected_to admin_moderation_queue_path(locale: :es)
    assert_equal "pending_review", listing.reload.status
  end

  test "the queue warns about suspicious prices" do
    listing = listings(:pending_review_gpu)
    listing.update_columns(price_cents: 1_000)
    Listing.published.where.not(id: listing.id).update_all(price_cents: 100_000)

    get admin_moderation_queue_path(locale: :es)

    assert_response :success
    assert_match I18n.t("admin.moderation.flags.suspicious_price", locale: :es), response.body
  end

  test "the queue warns about duplicated images across sellers" do
    listing = listings(:pending_review_gpu)
    attach_image(listing)

    other = Listing.create!(
      user: users(:buyer), category: categories(:cpus),
      title: "Duplicate photo test listing", description: "A listing with the same photo as another seller.",
      price_cents: 20_000, condition: :used_good, status: :published, published_at: Time.current,
      country_code: "ES"
    )
    attach_image(other)

    get admin_moderation_queue_path(locale: :es)

    assert_response :success
    assert_match I18n.t("admin.moderation.flags.duplicate", count: 1, locale: :es), response.body
  end

  test "bulk approval publishes every selected listing" do
    second = Listing.create!(
      user: users(:seller), category: categories(:cpus),
      title: "Second pending listing", description: "Another listing waiting for a moderation decision.",
      price_cents: 25_000, condition: :used_good, status: :pending_review, country_code: "ES"
    )

    post admin_bulk_listing_actions_path(locale: :es),
         params: { listing_ids: [ listings(:pending_review_gpu).id, second.id ], bulk_action: "approve" }

    assert_redirected_to admin_listings_path(locale: :es)
    assert listings(:pending_review_gpu).reload.published?
    assert second.reload.published?
    assert AdminAuditLog.where(action: "listing.bulk_approve").exists?
  end

  test "admin listing edit validates the game FPS JSON" do
    listing = listings(:published_gpu)

    patch admin_listing_path(listing, locale: :es),
          params: { listing: { game_fps_json: "{invalid", title: listing.title } }

    assert_response :unprocessable_entity
    assert_match I18n.t("admin.listings.form.game_fps"), response.body
  end

  test "admin listing edit updates labels, status and specs" do
    listing = listings(:published_gpu)

    patch admin_listing_path(listing, locale: :es),
          params: { listing: { labels: [ "rare", "deal" ], performance_score: 80,
                              game_fps_json: '{"fortnite":{"1080p":120}}',
                              title: listing.title, description: listing.description,
                              category_id: listing.category_id, price: "500.00",
                              status: "published" } }

    assert_redirected_to admin_listing_path(listing, locale: :es)
    listing.reload
    assert_equal %w[deal rare], listing.labels.sort
    assert_equal 80, listing.performance_score
    assert_equal({ "fortnite" => { "1080p" => 120 } }, listing.game_fps)
  end

  private

  def attach_image(listing)
    listing.images.attach(
      io: File.open(Rails.root.join("test/fixtures/files/gpu.jpg")),
      filename: "gpu.jpg", content_type: "image/jpeg"
    )
  end
end
