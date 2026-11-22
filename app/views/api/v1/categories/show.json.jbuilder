json.data do
  json.id @category.id
  json.slug @category.slug
  json.name @category.name
  json.path @category.path_slugs
  json.icon @category.icon
  json.listings_count @count
  json.children @children do |child|
    json.id child.id
    json.slug child.slug
    json.name child.name
    json.path child.path_slugs
    json.listings_count child.listings_count
  end
  json.filters @filters do |filter|
    json.key filter.key
    json.name filter.name
    json.input_type filter.input_type
    json.unit filter.unit
    json.options filter.filter_options do |option|
      json.value option.value
      json.label option.label
    end
  end
  json.labels @labels
end
json.meta({})
