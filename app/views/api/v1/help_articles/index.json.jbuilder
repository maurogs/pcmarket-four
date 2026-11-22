json.data @articles do |article|
  json.id article.id
  json.slug article.slug
  json.title article.title
  json.category article.category
  json.category_name I18n.t("help_articles.categories.#{article.category}", default: article.category.humanize)
  json.excerpt article.body.to_s.gsub(/<[^>]+>/, " ").squish.first(180)
  json.position article.position
  json.updated_at article.updated_at.iso8601
end
json.meta do
  json.partial! "api/v1/shared/pagination", pagy: @pagy
end
