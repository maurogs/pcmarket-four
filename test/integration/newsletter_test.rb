require "test_helper"

class NewsletterTest < ActionDispatch::IntegrationTest
  test "subscribing a valid email creates a pending subscriber and sends confirmation" do
    assert_difference -> { NewsletterSubscriber.count }, 1 do
      assert_enqueued_emails 1 do
        post newsletter_subscribers_path(locale: :es),
             params: { email: "new-reader@example.com" }
      end
    end

    subscriber = NewsletterSubscriber.find_by!(email: "new-reader@example.com")
    assert_equal "es", subscriber.locale
    assert_nil subscriber.confirmed_at
    assert_redirected_to root_path(locale: :es)
    follow_redirect!
    assert_match I18n.t("newsletter.subscribe.success"), response.body
  end

  test "subscribing with an invalid email does not create a subscriber" do
    assert_no_difference -> { NewsletterSubscriber.count } do
      post newsletter_subscribers_path(locale: :es), params: { email: "not-an-email" }
    end

    assert_redirected_to root_path(locale: :es)
    follow_redirect!
    assert_match I18n.t("newsletter.subscribe.invalid"), response.body
  end

  test "duplicate subscriptions are idempotent" do
    post newsletter_subscribers_path(locale: :es), params: { email: "repeat@example.com" }

    assert_no_difference -> { NewsletterSubscriber.count } do
      post newsletter_subscribers_path(locale: :es), params: { email: "REPEAT@example.com" }
    end

    assert_equal 1, NewsletterSubscriber.where(email: "repeat@example.com").count
  end

  test "confirming a subscription marks the subscriber as confirmed" do
    subscriber = NewsletterSubscriber.create!(email: "confirm-me@example.com", locale: "es")

    get confirm_newsletter_path(token: subscriber.token, locale: :es)

    assert_redirected_to root_path(locale: :es)
    assert subscriber.reload.confirmed?
  end

  test "an invalid confirmation token redirects with an alert" do
    get confirm_newsletter_path(token: "unknown-token", locale: :es)

    assert_redirected_to root_path(locale: :es)
    follow_redirect!
    assert_match I18n.t("newsletter.confirm.invalid"), response.body
  end

  test "turbo stream responses replace the form status" do
    post newsletter_subscribers_path(locale: :es),
         params: { email: "turbo@example.com" }, as: :turbo_stream

    assert_response :success
    assert_match "newsletter-form-status", response.body
    assert_match I18n.t("newsletter.subscribe.success"), response.body
  end
end
