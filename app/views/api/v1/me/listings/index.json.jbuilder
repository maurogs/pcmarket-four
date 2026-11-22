json.data @listings do |listing|
  json.partial! "api/v1/listings/listing", listing: listing
end
json.meta do
  json.partial! "api/v1/shared/pagination", pagy: @pagy
end
