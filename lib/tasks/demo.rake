namespace :demo do
  desc "Download and cache openly licensed demo photos into db/seeds/demo/image_manifest.json"
  task images: :environment do
    target = ENV.fetch("DEMO_IMAGES_PER_QUERY", Demo::ImageLibrary::DEFAULT_TARGET).to_i
    puts "Fetching demo images (#{target} per query). Optional keys: " \
         "UNSPLASH_ACCESS_KEY, PEXELS_API_KEY, PIXABAY_API_KEY."

    entries = Demo::ImageLibrary.call(target: target)
    puts "Manifest now has #{entries.size} images at db/seeds/demo/image_manifest.json."
    puts "Cached files live in storage/demo_images/ (gitignored)."
  end

  desc "Seed demo marketplace data (idempotent; honours DEMO_SCALE and DEMO_IMAGES)"
  task seed: :environment do
    Demo::Seed.call
  end

  desc "Delete demo records and their blobs, then seed them again"
  task reset: :environment do
    Demo::Reset.call
    Demo::Seed.call(force: true)
  end
end
