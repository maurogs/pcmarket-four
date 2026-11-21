unless Rails.env.production?
  madrid = Region.find_by(country_code: "ES", name: "Madrid") ||
           Region.find_by(country_code: "ES", name: "Comunidad de Madrid")

  admin = User.find_or_initialize_by(email: "admin@pcmarket.test")
  if admin.new_record?
    admin.assign_attributes(
      password: "Password123!",
      password_confirmation: "Password123!",
      first_name: "Ada",
      last_name: "Admin",
      role: :admin,
      status: :active,
      country_code: "ES",
      region: madrid,
      city: "Madrid",
      locale: "es",
      confirmed_at: Time.current,
      terms_accepted_at: Time.current
    )
    admin.save!
  end

  if Rails.env.development?
    seller = User.find_or_initialize_by(email: "seller@pcmarket.test")
    if seller.new_record?
      seller.assign_attributes(
        password: "Password123!",
        password_confirmation: "Password123!",
        first_name: Faker::Name.first_name,
        last_name: Faker::Name.last_name,
        role: :user,
        status: :active,
        country_code: "ES",
        region: madrid,
        city: "Madrid",
        locale: "es",
        confirmed_at: Time.current,
        terms_accepted_at: Time.current
      )
      seller.save!
    end

    store = seller.store || seller.build_store
    store.assign_attributes(
      name: "Falcon Tech",
      description: "Componentes de segunda mano revisados por técnicos.",
      store_type: :professional,
      verified: true,
      country_code: "ES",
      region: madrid,
      city: "Madrid"
    )
    store.save!

    demo_listings = [
      {
        category: "gpus",
        title: "NVIDIA GeForce RTX 4070 Super 12 GB",
        description: "Tarjeta gráfica en perfecto estado, con caja original y todos los accesorios incluidos.",
        price_cents: 54_900,
        original_price_cents: 69_900,
        condition: :used_like_new,
        specs: { "gpu_chipset" => "NVIDIA", "gpu_model" => "RTX 4070",
                 "gpu_memory" => "12GB" },
        labels: %w[mid_range deal],
        tags: %w[rgb black],
        featured: true
      },
      {
        category: "macbooks",
        title: "MacBook Pro 14 M3 512 GB",
        description: "Portátil Apple con chip M3, pantalla Liquid Retina XDR y 18 meses de garantía.",
        price_cents: 149_900,
        original_price_cents: 199_900,
        condition: :used_like_new,
        specs: { "cpu_brand" => "Apple", "memory_capacity" => "16GB",
                 "storage_capacity" => "512GB" },
        labels: %w[pro_gamer featured],
        tags: %w[minimalist whiteout],
        featured: true
      },
      {
        category: "consoles",
        title: "PlayStation 5 Slim con mando DualSense",
        description: "Consola en muy buen estado, con mando original, cables y caja. Lista para jugar.",
        price_cents: 39_900,
        original_price_cents: 49_900,
        condition: :used_good,
        specs: { "platform" => "PlayStation 5", "storage_capacity" => "1TB" },
        labels: %w[deal],
        tags: %w[compact white],
        featured: false
      },
      {
        category: "keyboards",
        title: "Keychron Q1 Pro teclado mecánico",
        description: "Teclado mecánico inalámbrico con estructura de aluminio, interruptores táctiles y reposamuñecas.",
        price_cents: 14_900,
        condition: :used_like_new,
        specs: { "keyboard_layout" => "ES", "keyboard_size" => "75%",
                 "switch_type" => "Tactile", "connection" => "Multi-mode" },
        labels: %w[rare],
        tags: %w[wood cozy],
        featured: false
      }
    ]

    demo_listings.each do |attributes|
      next if store.listings.exists?(title: attributes[:title])

      listing = store.listings.new(
        user: seller,
        category: Category.find_by!(slug: attributes[:category]),
        title: attributes[:title],
        description: attributes[:description],
        price_cents: attributes[:price_cents],
        original_price_cents: attributes[:original_price_cents],
        condition: attributes[:condition],
        status: :published,
        published_at: Time.current,
        quantity: 1,
        specs: attributes[:specs],
        labels: attributes[:labels],
        tags: attributes[:tags],
        featured_until: attributes[:featured] ? 7.days.from_now : nil,
        country_code: "ES",
        region: madrid,
        city: "Madrid",
        accepts_offers: true
      )
      listing.save!
    end

    sold_listing = store.listings.find_by(title: "Lenovo ThinkPad X1 Carbon Gen 11")
    if sold_listing.nil?
      sold_listing = store.listings.new(
        user: seller,
        category: Category.find_by!(slug: "ultrabooks"),
        title: "Lenovo ThinkPad X1 Carbon Gen 11",
        description: "Portátil profesional de 14 pulgadas, ligero, silencioso y con batería en buen estado.",
        price_cents: 85_000,
        condition: :used_good,
        status: :sold,
        published_at: 12.days.ago,
        quantity: 1,
        specs: { "cpu_brand" => "Intel", "memory_capacity" => "16GB" },
        labels: %w[value],
        tags: %w[blackout minimalist],
        country_code: "ES",
        region: madrid,
        city: "Madrid"
      )
      sold_listing.save!
    end
  end
end
