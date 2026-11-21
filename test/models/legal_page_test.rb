require "test_helper"

class LegalPageTest < ActiveSupport::TestCase
  setup do
    Rails.cache.clear
  end

  test "resolve falls back from the request locale to the country default and English" do
    page = legal_pages(:terms_spain)

    assert_equal page, LegalPage.resolve(country: countries(:spain), locale: "es", slug: "terms")
    assert_equal page, LegalPage.resolve(country: countries(:spain), locale: "de", slug: "terms")
    assert_nil LegalPage.resolve(country: countries(:spain), locale: "en", slug: "privacy")
  end

  test "rendered body interpolates company settings and escapes values" do
    Setting.set("company_legal_name", "ACME <Test> S.L.")
    page = LegalPage.create!(
      slug: "legal_notice", country_code: "ES", locale: "es",
      title: "Aviso legal",
      body: "<p>Titular: {{company_legal_name}}</p><p>{{support_email}}</p>"
    )

    assert_includes page.rendered_body, "ACME &lt;Test&gt; S.L."
    assert_includes page.rendered_body, Setting.get("support_email")
  end

  test "table of contents exposes h2 headings with stable ids" do
    page = LegalPage.create!(
      slug: "privacy", country_code: "ES", locale: "es",
      title: "Privacidad",
      body: "<p>Intro</p><h2>Responsable</h2><p>Texto</p><h2>Derechos</h2>"
    )

    assert_equal %w[responsable-1 derechos-2], page.toc.map { |entry| entry[:id] }
    assert_includes page.rendered_body, "id=\"responsable-1\""
  end
end
