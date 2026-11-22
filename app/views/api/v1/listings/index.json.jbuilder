json.data @listings do |listing|
  json.partial! "api/v1/listings/listing", listing: listing
end

json.meta do
  json.partial! "api/v1/shared/pagination", pagy: @pagy
  json.sort @search.sort
  json.query @search.query
  json.category_id @search.category&.id
  json.facets @search.filter_definitions do |definition|
    counts = @search.facets[definition.key] || {}
    next if counts.empty?

    json.key definition.key
    json.name definition.name
    json.options counts.sort_by { |_value, count| -count }.map do |value, count|
      option = definition.filter_options.find { |item| item.value == value.to_s }
      {
        value: value,
        label: option&.label || value,
        count: count,
        selected: Array(@search.spec_filters[definition.key]).include?(value.to_s)
      }
    end
  end
  json.active_filters @search.active_filters do |filter|
    json.key filter.key
    json.value filter.value
    json.label filter.label
  end
end
