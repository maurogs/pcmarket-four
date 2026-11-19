# Opt-in demo data for local development (see README: `DEMO=1 bin/rails db:seed`).
#
# Creates ~30 Spanish demo users (emails @demo.example.com), 8 stores
# (3 business), and ~250 published listings built from the seeded catalog so
# every spec filter, label, theme tag and chipset link has results: discounts,
# featured slots, seller tags, sold and pending-review listings included.
#
# Skipped entirely once its listings exist (≥ 200 demo listings), so repeated
# seed runs do not duplicate data. Test env: never loaded (db/seeds.rb gate).

DEMO_EMAIL_SUFFIX = "@demo.example.com".freeze
DEMO_TARGET_LISTINGS = 240

skip = Listing.joins(store: :user).where("users.email LIKE ?", "%#{DEMO_EMAIL_SUFFIX}").count >= 200
if skip
  Rails.logger.info "Demo seed skipped (demo listings already present)."
else
  Faker::Config.locale = "es"
  es = Country.find_by(code: "ES") || Country.enabled.first
  provinces = SpanishProvince.codes
  provinces = [ nil ] if provinces.empty?

  pick = lambda do |array, n = nil|
    array = Array(array)
    n.nil? ? array.sample : Array(array.sample(n))
  end
  money = ->(min, max) { (min..max).step(100).to_a.sample }

  labels_by_slug = ProductLabel.active.index_by(&:slug)
  theme_tags = SellerTag.active.where(slug: %w[anime minimalist rgb]).index_by(&:slug)
  category_filters = Category.includes(filter_definitions: :filter_options).index_by(&:slug)

  pick_specs = lambda do |category|
    specs = {}
    definitions = category.filter_definitions.active.to_a
    pick.call(definitions, rand(1..2)).each do |definition|
      next if !definition.boolean? && definition.filter_options.active.none?

      values =
        if definition.boolean?
          pick.call(%w[true false])
        else
          pick.call(definition.filter_options.active.map(&:value), rand(1..2))
        end
      specs[definition.key] = values if values.present?
    end
    specs
  end

  # --- Users + stores --------------------------------------------------------
  users = Array.new(30) do |i|
    User.find_or_create_by!(email: format("demo%02d%s", i + 1, DEMO_EMAIL_SUFFIX)) do |u|
      u.username = User.generate_username(Faker::Internet.username(separators: %w[_]) + i.to_s)
      u.first_name = Faker::Name.first_name
      u.last_name = Faker::Name.last_name
      u.phone = Faker::PhoneNumber.phone_number
      u.country = es
      u.locale = "es"
      u.password = Devise.friendly_token(20)
      u.skip_confirmation!
    end
  end

  store_profiles = [
    { kind: :business, name: "TecnoMadrid Store", verified: true },
    { kind: :individual, name: nil, vacation: false },
    { kind: :individual, name: nil, vacation: false },
    { kind: :business, name: "Barcelona PC Parts", verified: true },
    { kind: :individual, name: nil, vacation: true },
    { kind: :individual, name: nil, vacation: false },
    { kind: :business, name: "Valencia Retro Gaming", verified: false },
    { kind: :individual, name: nil, vacation: false }
  ]

  stores = store_profiles.each_with_index.map do |profile, i|
    user = users[i]
    code = provinces.sample
    store = Store.find_or_initialize_by(user: user)
    store.update!(
      name: profile[:name] || "#{user.first_name} #{user.last_name}".first(60),
      bio: Faker::Lorem.paragraph_by_chars(number: 180),
      kind: profile[:kind],
      business_name: profile[:kind] == :business ? profile[:name] : nil,
      tax_id: profile[:kind] == :business ? "B#{Faker::Number.number(digits: 8)}" : nil,
      country: es,
      city: code && SpanishProvince.name(code, locale: "es"),
      province: code,
      vacation_mode: profile[:vacation] == true,
      followers_count: rand(4..900),
      sales_count: rand(0..420),
      ratings_count: rand(0..180),
      rating_avg: [ rand(3.2..5.0).round(2), 0 ].max
    )
    store.verified! if profile[:verified]
    store
  end

  # --- Listings ---------------------------------------------------------------
  catalog = [
    [ "gaming-pcs", 45, money.(60_000, 320_000), %w[value_pcs mid_range_pcs pro_gamer_pcs] ],
    [ "gpus", 70, money.(12_000, 190_000), %w[value_gpus mid_range_gpus pro_gamer_gpus] ],
    [ "cpus", 25, money.(6_000, 80_000), %w[value_cpus mid_range_cpus pro_gamer_cpus] ],
    [ "laptops", 30, money.(35_000, 240_000), [] ],
    [ "monitors", 15, money.(9_000, 70_000), [] ],
    [ "keyboards", 12, money.(3_500, 22_000), [] ],
    [ "consoles", 10, money.(12_000, 60_000), [] ],
    [ "workstations", 8, money.(90_000, 420_000), [] ]
  ]

  created = []
  catalog.each do |slug, count, base_price, label_slugs|
    category = category_filters[slug]
    next if category.nil?

    count.times do |i|
      store = pick.call(stores)
      code = provinces.sample
      price = base_price + [ money.(-15_000, 15_000), 0 ].sample
      price = 500 if price < 500
      discounted = rand < 0.35
      listing = Listing.create!(
        store: store,
        category: category,
        title: "#{Faker::Company.name} #{Faker::Commerce.product_name} #{i + 1}".first(120),
        description: Faker::Lorem.paragraphs(number: 2).join("\n\n"),
        price_cents: price,
        original_price_cents: discounted ? (price * rand(1.1..1.45)).round : nil,
        currency: "EUR",
        condition: Listing.conditions.keys.sample,
        shipping_method: Listing.shipping_methods.keys.sample,
        shipping_price_cents: rand(0..800),
        free_shipping: rand < 0.4,
        ships_within_days: rand(1..7),
        allow_offers: rand < 0.6,
        quantity: rand(1..3),
        specs: pick_specs.call(category),
        highlights: rand < 0.5 ? pick.call(%w[Invoice Original\ box Warranty], rand(1..2)) : [],
        country: es,
        province: code,
        city: code && SpanishProvince.name(code, locale: "es")
      )
      listing.submit!
      listing.approve!
      listing.update_columns(
        published_at: rand(0.5.hours..30.days).ago,
        views_count: rand(5..9_000),
        watchers_count: rand(0..260),
        favorites_count: rand(0..120)
      )

      label = labels_by_slug[label_slugs.sample] if label_slugs.any? && rand < 0.55
      listing.product_labels << label if label
      if slug == "gaming-pcs" && rand < 0.6
        tag = pick.call(theme_tags.values.compact)
        listing.seller_tags << tag if tag
      end
      created << listing
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.warn "Demo seed skipped a listing: #{e.message}"
    end
  end

  # Featured slots, sold history and a few listings still awaiting review.
  pick.call(created, 18).each do |listing|
    listing.update_columns(featured_until: rand(6.hours..14.days).from_now)
  end
  pick.call(created.select(&:published?), 26).each do |listing|
    listing.mark_sold!
    listing.update_columns(sold_at: rand(1.hour..25.days).ago)
  end
  fresh = Listing.joins(store: :user).where("users.email LIKE ?", "%#{DEMO_EMAIL_SUFFIX}%")
                .where(status: "published").where(featured_until: nil)
  pick.call(fresh.limit(400).to_a, 12).each(&:return_to_review!)

  Rails.logger.info "Demo seed: #{created.size} listings for #{stores.size} stores."
  puts "Demo seed: #{created.size} listings across #{stores.size} stores (users @demo.example.com)."
end
