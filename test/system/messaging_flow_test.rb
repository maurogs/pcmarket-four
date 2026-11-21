require "application_system_test_case"

class MessagingFlowTest < ApplicationSystemTestCase
  test "buyer messages seller and seller sees it in the inbox" do
    listing = listings(:published_gpu)

    using_session(:buyer) do
      sign_in_as(users(:buyer))
      visit "/es/l/#{listing.slug}"
      first(:button, I18n.t("listings.show.message_seller", locale: :es)).click

      assert_current_path(%r{/es/conversations/\d+})
      form = find("form[action*='/messages']")
      form.find("textarea[name='message[body]']").set("Hola, ¿sigue disponible la tarjeta?")
      form.native.submit
      assert_text "Hola, ¿sigue disponible la tarjeta?"
      assert_text "Hola, ¿sigue disponible la tarjeta?"
    end

    using_session(:seller) do
      sign_in_as(users(:seller))
      visit "/es/conversations"

      assert_text "Hola, ¿sigue disponible la tarjeta?"
      assert_text users(:buyer).display_name
    end
  end

  private

  def sign_in_as(user)
    visit "/es/users/sign_in"
    accept_cookies
    fill_in "user_email", with: user.email
    fill_in "user_password", with: "Password123!"
    click_button I18n.t("auth.sign_in.submit", locale: :es)
    assert_selector "header #account-menu", visible: :all
  end

  def accept_cookies
    label = I18n.t("layout.cookies.accept_all", locale: :es)
    click_button label if page.has_button?(label, wait: 0)
  end
end
