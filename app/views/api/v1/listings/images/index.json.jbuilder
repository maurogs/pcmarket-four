json.data @listing.ordered_images.map { |attachment| api_image_urls(attachment) }
json.meta({})
