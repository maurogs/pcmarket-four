json.data do
  json.id @article.id
  json.slug @article.slug
  json.title @article.title
  json.category @article.category
  json.body_html @article.body_html
  json.helpful_count @article.helpful_count
  json.unhelpful_count @article.unhelpful_count
  json.updated_at @article.updated_at.iso8601
end
json.meta({})
