# Generates 5,000 listings in a rolled-back transaction and prints the
# PostgreSQL plan for the main ListingSearch query.
#
#   RAILS_ENV=test bin/rails db:test:prepare
#   RAILS_ENV=test bin/rails runner script/search_explain.rb

ActiveRecord::Base.transaction do
  country = Country.find_or_create_by!(code: "ES") do |record|
    record.name_key = "countries.ES"
    record.enabled = true
    record.currency = "EUR"
  end
  country.update!(enabled: true)

  region = Region.find_or_create_by!(country_code: "ES", code: "EX") do |record|
    record.name = "Explain Region"
  end

  user = User.create!(
    email: "explain-#{SecureRandom.hex(4)}@example.com",
    password: "Password123!",
    password_confirmation: "Password123!",
    first_name: "Explain",
    last_name: "User",
    country_code: "ES",
    region: region,
    locale: "es",
    confirmed_at: Time.current,
    terms_accepted_at: Time.current
  )

  root = Category.create!(
    names: { "es" => "Explain Root", "en" => "Explain Root" },
    slug: "explain-root-#{SecureRandom.hex(4)}",
    position: 0,
    active: true
  )
  leaf = Category.create!(
    names: { "es" => "Explain GPUs", "en" => "Explain GPUs" },
    slug: "explain-gpus-#{SecureRandom.hex(4)}",
    parent: root,
    position: 0,
    active: true
  )
  definition = FilterDefinition.find_or_create_by!(key: "cpu_brand") do |record|
    record.names = { "es" => "CPU", "en" => "CPU" }
    record.input_type = :checkbox
  end
  CategoryFilter.create!(category: leaf, filter_definition: definition, position: 0)

  now = Time.current
  rows = 5_000.times.map do |index|
    {
      user_id: user.id,
      category_id: leaf.id,
      title: "Explain listing #{index}",
      slug: "explain-listing-#{index}-#{SecureRandom.hex(3)}",
      description: "Generated listing used to analyse the search query plan.",
      price_cents: 10_000 + (index * 60),
      condition: index.even? ? 2 : 3,
      status: 2,
      published_at: now - index.minutes,
      quantity: 1,
      specs: { "cpu_brand" => index.even? ? "intel" : "amd", "vram" => (8 + (index % 4) * 8).to_s },
      country_code: "ES",
      region_id: region.id,
      city: "Madrid",
      shipping_available: true,
      local_pickup: index % 3 == 0,
      free_shipping: index % 10 == 0,
      original_price_cents: index % 5 == 0 ? 20_000 + index : nil,
      created_at: now,
      updated_at: now
    }
  end
  Listing.insert_all!(rows)

  search = ListingSearch.new(
    params: {
      min_price: "200",
      max_price: "2500",
      condition: [ "used_like_new" ],
      f: { cpu_brand: [ "intel" ] },
      shipping: [ "ship" ],
      sort: "newest"
    },
    category: leaf
  )

  puts "Total matches: #{search.total_count}"
  puts "SQL:\n#{search.relation.to_sql}\n\n"
  plan = ActiveRecord::Base.connection.select_all(
    "EXPLAIN (ANALYZE, BUFFERS) #{search.relation.to_sql}"
  )
  plan.rows.each { |row| puts row.first }

  raise ActiveRecord::Rollback
end
