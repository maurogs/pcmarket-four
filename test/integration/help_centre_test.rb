require "test_helper"

class HelpCentreTest < ActionDispatch::IntegrationTest
  setup do
    Rails.cache.clear
    @article = HelpArticle.create!(
      slug: "change-your-password",
      category: "account",
      position: 1,
      titles: { "es" => "Cómo cambiar tu contraseña", "en" => "How to change your password" },
      bodies: {
        "es" => "<h2>Pasos</h2><p>Abre tu cuenta y elige una contraseña segura.</p>",
        "en" => "<h2>Steps</h2><p>Open your account and choose a safe password.</p>"
      },
      published: true
    )
  end

  test "index lists categories, popular articles and contact details" do
    get "/es/help"

    assert_response :success
    assert_select "h1", text: I18n.t("content.help.index.title", locale: :es)
    assert_select "a", text: I18n.t("content.help.categories.account", locale: :es)
    assert_includes response.body, @article.title(:es)
  end

  test "search is accent-insensitive on the current locale" do
    get "/es/help", params: { q: "contrasena" }

    assert_response :success
    assert_includes response.body, @article.title(:es)
  end

  test "search respects the current locale" do
    get "/en/help", params: { q: "password" }

    assert_response :success
    assert_includes response.body, "How to change your password"
    assert_not_includes response.body, "Cómo cambiar tu contraseña"
  end

  test "shows an article with related links and feedback form" do
    get "/es/help/change-your-password"

    assert_response :success
    assert_select "h1", text: @article.title(:es)
    assert_select "form[action*='/feedback']"
    assert_includes response.body, "\"@type\":\"Article\""
    assert_includes response.body, "\"@type\":\"BreadcrumbList\""
  end

  test "records one feedback per session and updates the vote" do
    assert_difference -> { HelpArticleFeedback.count }, 1 do
      post "/es/help/change-your-password/feedback", params: { helpful: "yes" }
    end
    assert_redirected_to help_article_path(@article.slug, locale: :es, anchor: "feedback")
    assert HelpArticleFeedback.last.helpful?

    assert_no_difference -> { HelpArticleFeedback.count } do
      post "/es/help/change-your-password/feedback", params: { helpful: "no" }
    end
    assert_not HelpArticleFeedback.last.reload.helpful?
  end
end
