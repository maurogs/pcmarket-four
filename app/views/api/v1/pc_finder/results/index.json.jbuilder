json.data @results do |result|
  listing = @listings[result.listing_id]
  next if listing.nil?

  json.score result.score.to_f.round(2)
  json.performance result.performance.to_f.round(2)
  json.value result.value.to_f.round(2)
  json.fit result.fit
  json.estimated_fps result.estimated_fps
  json.listing do
    json.partial! "api/v1/listings/listing", listing: listing
  end
end
json.meta do
  json.partial! "api/v1/shared/pagination", pagy: @pagy
end
