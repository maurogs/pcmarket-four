json.data do
  json.id @legal_page.id
  json.slug @legal_page.slug
  json.country_code @legal_page.country_code
  json.locale @legal_page.locale
  json.title @legal_page.title
  json.body_html @legal_page.rendered_body
  json.version @legal_page.version
  json.published_at @legal_page.published_at&.iso8601
  json.updated_at @legal_page.updated_at.iso8601
  json.toc @legal_page.toc
  json.available_locales LegalPage.available_locales_for(country_code: @legal_page.country_code,
                                                          slug: @legal_page.slug)
end
json.meta({})
