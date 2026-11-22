json.data @saved_searches do |saved_search|
  json.partial! "api/v1/saved_searches/saved_search", saved_search: saved_search
end
json.meta do
  json.partial! "api/v1/shared/pagination", pagy: @pagy
end
