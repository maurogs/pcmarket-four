json.data do
  json.partial! "api/v1/listings/listing", listing: @listing
end
json.meta({})
