require "application_system_test_case"

class AdminModerationFlowTest < ApplicationSystemTestCase
  test "a moderator approves a pending listing from the queue" do
    listing = listings(:pending_review_gpu)

    visit "/es/users/sign_in"
    fill_in "user_email", with: users(:moderator).email
    fill_in "user_password", with: "Password123!"
    click_button I18n.t("auth.sign_in.submit", locale: :es)

    assert_selector "button[aria-label='#{I18n.t("layout.header.account", locale: :es)}']"

    visit "/es/admin/moderation"
    assert_selector "h1", text: I18n.t("admin.moderation.title", locale: :es)

    within first("article") do
      click_button I18n.t("admin.actions.approve", locale: :es), match: :first
    end

    assert_text I18n.t("admin.moderation.approved", title: listing.title, locale: :es, default: listing.title)
    assert_equal "published", listing.reload.status

    visit "/es/l/#{listing.slug}"
    assert_selector "h1", text: listing.title
    assert_no_selector "text", text: I18n.t("listings.statuses.pending_review", locale: :es)

    clear_browser_state
  end
end
