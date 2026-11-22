json.data do
  json.partial! "api/v1/saved_searches/saved_search", saved_search: @saved_search
end
json.meta({})
