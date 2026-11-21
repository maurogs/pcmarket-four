require "test_helper"

class LegalPagesTest < ActionDispatch::IntegrationTest
  setup do
    Rails.cache.clear
  end

  test "serves the Spanish legal page by default" do
    get "/es/legal/terms"

    assert_response :success
    assert_select "h1", text: legal_pages(:terms_spain).title
    assert_select "nav[aria-label='#{I18n.t("content.legal_page.breadcrumb", locale: :es)}']"
  end

  test "falls back to the country default locale before English" do
    LegalPage.create!(
      slug: "privacy", country_code: "ES", locale: "es",
      title: "Privacidad ES", body: "<h2>Datos</h2><p>Contenido</p>"
    )

    get "/en/legal/privacy"

    assert_response :success
    assert_select "h1", text: "Privacidad ES"
    assert_select "h2", text: "Datos"
  end

  test "returns 404 for a disabled country to non-staff visitors" do
    get "/es/legal/terms", params: { country: "FR" }

    assert_response :not_found
  end

  test "staff can preview a disabled country" do
    LegalPage.create!(
      slug: "terms", country_code: "FR", locale: "fr",
      title: "Conditions FR", body: "<h2>Objet</h2><p>Texte</p>"
    )
    sign_in users(:admin)

    get "/es/legal/terms", params: { country: "FR" }

    assert_response :success
    assert_select "h1", text: "Conditions FR"
  end

  test "interpolates company placeholders from settings" do
    Setting.set("company_legal_name", "PCMarket Test S.L.")
    LegalPage.create!(
      slug: "legal_notice", country_code: "ES", locale: "es",
      title: "Aviso legal", body: "<h2>Titular</h2><p>{{company_legal_name}}</p>"
    )

    get "/es/legal/legal_notice"

    assert_response :success
    assert_includes response.body, "PCMarket Test S.L."
  end

  test "canonical and hreflang only include locales that exist for the country" do
    LegalPage.create!(
      slug: "terms", country_code: "ES", locale: "en",
      title: "Terms EN", body: "<h2>Rules</h2><p>Text</p>"
    )

    get "/es/legal/terms"

    assert_response :success
    assert_select "link[rel='alternate'][hreflang='es']", count: 1
    assert_select "link[rel='alternate'][hreflang='en']", count: 1
    assert_select "link[rel='alternate'][hreflang='fr']", count: 0
  end

  test "cookie page offers the consent preferences button" do
    LegalPage.create!(
      slug: "cookies", country_code: "ES", locale: "es",
      title: "Cookies", body: "<h2>Necesarias</h2><p>Texto</p>"
    )

    get "/es/legal/cookies"

    assert_response :success
    assert_select "button[data-action='cookie-consent#open']"
  end
end
