json.data @favorites do |favorite|
  json.id favorite.id
  json.created_at favorite.created_at.iso8601
  json.listing do
    json.partial! "api/v1/listings/listing", listing: favorite.listing
  end
end
json.meta do
  json.partial! "api/v1/shared/pagination", pagy: @pagy
end
