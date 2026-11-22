require "digest"
require "fileutils"
require "securerandom"

module Demo
  # Idempotent demo marketplace seed. Records are tagged through the
  # `@demo.pcmarket.test` email domain so a reset can remove exactly what this
  # task created.
  class Seed
    DEMO_DOMAIN = "demo.pcmarket.test".freeze
    DEMO_EMAIL_PATTERN = "%@#{DEMO_DOMAIN}".freeze
    PASSWORD = "Password123!".freeze
    FAKER_SEED = 42

    CONDITION_POOL = (
      [ "used_like_new" ] * 40 + [ "used_good" ] * 35 + [ "new_sealed" ] * 10 +
      [ "new_open_box" ] * 8 + [ "used_fair" ] * 5 + [ "for_parts" ] * 2
    ).freeze

    CONDITION_LABELS = {
      "new_sealed" => "precintado", "new_open_box" => "caja abierta",
      "used_like_new" => "como nuevo", "used_good" => "muy buen estado",
      "used_fair" => "con marcas de uso", "for_parts" => "para piezas"
    }.freeze

    REJECTION_REASONS = [
      "Faltan fotos reales del producto.",
      "El precio no es coherente con el estado indicado.",
      "La descripción incluye datos de contacto.",
      "El anuncio no cumple la política de artículos prohibidos."
    ].freeze

    MESSAGE_BODIES = [
      "Hola, ¿sigue disponible? Me interesa bastante.",
      "¿Podrías enviarme alguna foto más del lateral y de los puertos?",
      "Está en muy buen estado, apenas lo he usado en el último año.",
      "¿Aceptas envío a península? ¿Cuánto tardarías en enviarlo?",
      "Te lo puedo enviar mañana por la mañana con seguimiento incluido.",
      "¿Tiene algún defecto estético que no se vea en las fotos?",
      "Perfecto, entonces quedamos así. Muchas gracias.",
      "¿La caja original y los cables están incluidos?",
      "Sí, incluye caja, cables y todos los accesorios originales.",
      "¿Podrías bajar un poco el precio si lo compro hoy?",
      "Te dejo mi correo por si prefieres hablar fuera: demo.comprador@example.com",
      "Pásame un Bizum al 600 123 456 y te lo reservo ahora mismo."
    ].freeze

    def self.call(scale: nil, images: nil, force: false)
      new(scale: scale, images: images, force: force).call
    end

    # Catalogue names are usually descriptive enough on their own. For short
    # model names (for example "Antec C8"), add the category, brand or model
    # until the title satisfies Listing's minimum length. Never use condition.
    def self.title_for(product, category)
      title = product[:title].to_s.squish
      qualifiers = [
        category.name("es"),
        product[:brand],
        product[:model],
        product[:capacity]
      ].compact_blank.map { |value| value.to_s.squish }.uniq

      qualifiers.each do |qualifier|
        break if title.length >= Listing::MIN_TITLE_LENGTH
        next if qualifier.blank? || title.downcase.include?(qualifier.downcase)

        title = "#{title} #{qualifier}".squish
      end

      if title.length < Listing::MIN_TITLE_LENGTH
        fallback = [ product[:brand], product[:model], product[:capacity], category.name("es") ]
                   .compact_blank.map { |value| value.to_s.squish }
        title = "#{title} #{fallback.join(' ')}".squish
      end

      title.truncate(Listing::MAX_TITLE_LENGTH)
    end

    attr_reader :scale, :images, :force

    def initialize(scale: nil, images: nil, force: false)
      @scale = (scale || ENV.fetch("DEMO_SCALE", "1")).to_f.clamp(0.01, 1.0)
      @images = images.nil? ? ENV.fetch("DEMO_IMAGES", "1") != "0" : images
      @force = force
      @now = Time.current
      @rng = Random.new(FAKER_SEED)
    end

    def call
      if already_seeded? && !force
        puts "Demo data already present (scale #{format('%.2f', scale)}); skipping."
        return summary
      end

      started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      with_seed_environment do
        preload_reference_data
        ActiveRecord::Base.transaction do
          create_staff
          create_buyers
          create_sellers_and_stores
          create_listings
          create_favorites_follows_and_searches
          create_conversations
          create_orders
          create_reviews
          create_notifications_reports_and_marketing
          update_counter_caches
        end
      end
      elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at

      print_summary(elapsed)
      summary
    end

    private

    def scaled(count)
      [ (count * scale).round, 1 ].max
    end

    def chance(probability)
      @rng.rand < probability
    end

    def with_seed_environment
      previous = {
        locale: Faker::Config.locale,
        seeding: Current.seeding
      }
      Current.seeding = true
      Faker::Config.locale = :es
      Faker::Config.random = Random.new(FAKER_SEED)
      yield
    ensure
      Faker::Config.locale = previous[:locale]
      Current.seeding = previous[:seeding]
    end

    def already_seeded?
      User.where("email LIKE ?", DEMO_EMAIL_PATTERN).exists? ||
        User.exists?(email: "moderator@pcmarket.test")
    end

    def preload_reference_data
      @regions = Region.where(country_code: "ES").index_by(&:name)
      all_categories = Category.active.to_a
      parent_ids = all_categories.filter_map do |category|
        category.ancestry.to_s.split("/").last&.to_i
      end.uniq
      @leaf_categories = all_categories.reject { |category| parent_ids.include?(category.id) }
      @effective_filters = {}
      @image_entries = load_image_entries
    end

    # ---------------------------------------------------------------- people

    def create_staff
      @admin = find_or_create_staff(
        email: "admin@pcmarket.test", role: :admin,
        first_name: "Ada", last_name: "Admin"
      )
      @moderator = find_or_create_staff(
        email: "moderator@pcmarket.test", role: :moderator,
        first_name: "Marta", last_name: "Moderadora"
      )
    end

    def find_or_create_staff(email:, role:, first_name:, last_name:)
      user = User.find_or_initialize_by(email: email)
      return user if user.persisted?

      madrid = @regions["Madrid"]
      user.assign_attributes(
        password: PASSWORD, password_confirmation: PASSWORD,
        first_name: first_name, last_name: last_name, role: role, status: :active,
        country_code: "ES", region: madrid, city: "Madrid", locale: "es",
        confirmed_at: @now, terms_accepted_at: @now
      )
      user.save!
      user
    end

    def create_buyers
      @buyers = Array.new(scaled(60)) do |index|
        create_demo_user(email: "buyer#{index + 1}@#{DEMO_DOMAIN}", role: :user,
                         avatar: (index % 6).zero?)
      end
    end

    def create_sellers_and_stores
      @professional_stores = []
      @professional_users = []

      Catalog::STORE_DEFINITIONS.first(scaled(Catalog::STORE_DEFINITIONS.size))
             .each_with_index do |definition, index|
        user = create_demo_user(
          email: "store#{index + 1}@#{DEMO_DOMAIN}", role: :user,
          city: definition[:city], region_name: definition[:region],
          first_name: Faker::Name.first_name, last_name: Faker::Name.last_name
        )
        store = user.create_store!(
          name: definition[:name],
          description: "Tienda especializada en tecnología de segunda mano revisada. " \
                       "Montamos y probamos cada equipo antes de publicarlo.",
          store_type: :professional,
          company_name: definition[:company],
          tax_id: Catalog.valid_cif(index + 101),
          verified: index < 9,
          return_policy: "Aceptamos devoluciones durante 14 días naturales si el producto " \
                         "no coincide con la descripción.",
          shipping_policy: "Enviamos en 24-48 horas laborables con embalaje reforzado y " \
                           "seguimiento. Recogida gratuita en tienda con cita previa.",
          country_code: "ES",
          region: @regions[definition[:region]],
          city: definition[:city]
        )
        attach_store_branding(store, definition)
        attach_user_avatar(user, index) if images_enabled? && (index % 3).zero?
        @professional_stores << store
        @professional_users << user
      end

      @individual_sellers = Array.new(scaled(40)) do |index|
        create_demo_user(email: "seller#{index + 1}@#{DEMO_DOMAIN}", role: :user,
                         avatar: images_enabled? && (index % 5).zero?)
      end

      @individual_sellers.each do |user|
        store = user.ensure_store!
        store.update_columns(
          description: "Particular aficionado al hardware. Vendo componentes y equipos " \
                       "de mi colección, siempre probados antes de enviar.",
          return_policy: "Acepto devoluciones en 14 días si el artículo no funciona.",
          shipping_policy: "Envío por Correos o SEUR con seguimiento. También entrego en mano.",
          region_id: user.region_id,
          city: user.city,
          country_code: "ES"
        )
      end

      @sellers = @professional_users + @individual_sellers
      @stores = @professional_stores + @individual_sellers.map(&:store)
    end

    def create_demo_user(email:, role:, city: nil, region_name: nil, first_name: nil,
                         last_name: nil, avatar: false)
      location = Catalog.locations.sample(random: @rng)
      city ||= location[0]
      region_name ||= location[1]
      user = User.create!(
        email: email,
        password: PASSWORD,
        password_confirmation: PASSWORD,
        first_name: first_name.presence || Faker::Name.first_name,
        last_name: last_name.presence || Faker::Name.last_name,
        role: role,
        status: :active,
        country_code: "ES",
        region: @regions[region_name],
        city: city,
        locale: chance(0.12) ? "en" : "es",
        confirmed_at: @now,
        terms_accepted_at: @now,
        accepts_marketing: chance(0.45),
        last_seen_at: @now - @rng.rand(0..20).days
      )
      attach_user_avatar(user, email.hash.abs) if avatar
      user
    end

    # -------------------------------------------------------------- listings

    def create_listings
      allocation = category_allocation
      categories = allocation.flat_map { |category, count| [ category ] * count }
                               .shuffle(random: @rng)
      @listings = []

      categories.each_with_index do |category, index|
        seller = @sellers[index % @sellers.size]
        product = Catalog.product_for(category.slug, @rng)
        next if product.blank?

        listing = build_listing(category, seller, product, index, categories.size)
        attach_listing_images(listing, category)
        @listings << listing
      end
    end

    def category_allocation
      target = scaled(600)
      weighted = @leaf_categories.map do |category|
        [ category, Catalog::CATEGORY_WEIGHTS.fetch(category.slug, 2) ]
      end

      if target < weighted.size
        return weighted.sort_by { |_category, weight| -weight }.first(target)
                       .to_h { |category, _weight| [ category, 1 ] }
      end

      total_weight = weighted.sum { |_category, weight| weight }.to_f
      counts = weighted.to_h do |category, weight|
        [ category, [ 1, (target * weight / total_weight).floor ].max ]
      end

      remaining = target - counts.values.sum
      index = 0
      while remaining.positive?
        counts[weighted[index % weighted.size].first] += 1
        remaining -= 1
        index += 1
      end

      counts
    end

    def build_listing(category, seller, product, index, total)
      condition = CONDITION_POOL.sample(random: @rng)
      price = rounded_demo_price(product[:price_cents] * Catalog.condition_multiplier(condition))
      price = [ price, 100 ].max
      discounted = chance(0.3)
      status = status_for(index, total)
      published_at = published_at_for(status)
      pc = %w[gaming-pcs creator-rigs streaming-rigs local-ai-rigs].include?(category.slug)
      game_fps = pc ? fps_table(product[:gpu_model]) : {}
      labels = labels_for(price, discounted, status)
      specs = specs_for(category, product[:specs])
      free_shipping = chance(0.2)

      listing = seller.listings.new(
        category: category,
        store: seller.store,
        title: listing_title(product, category),
        description: listing_description(product, category, condition, specs, game_fps),
        price_cents: price,
        original_price_cents: discounted ? original_price_for(price) : nil,
        brand: product[:brand],
        condition: condition,
        status: status == :published ? :published : status,
        rejection_reason: status == :rejected ? REJECTION_REASONS.sample(random: @rng) : nil,
        reviewed_at: status == :rejected ? @now : nil,
        reviewed_by_id: status == :rejected ? @admin.id : nil,
        published_at: published_at,
        quantity: 1,
        specs: specs,
        game_fps: game_fps,
        performance_score: product[:tier],
        country_code: "ES",
        region: seller.region,
        city: seller.city,
        postal_code: postal_code_for(seller),
        shipping_available: chance(0.85) || free_shipping,
        local_pickup: chance(0.6),
        shipping_price_cents: shipping_price(free_shipping),
        free_shipping: free_shipping,
        ships_within_days: @rng.rand(1..5),
        accepts_offers: chance(0.65),
        featured_until: status == :published && chance(0.08) ? @now + @rng.rand(7..21).days : nil,
        views_count: @rng.rand(15..2_500),
        labels: labels,
        tags: Listing::TAGS.sample(@rng.rand(1..3), random: @rng)
      )

      listing.save!
      listing
    end

    def status_for(index, total)
      percentile = index.to_f / total
      return :published if percentile < 0.85
      return :pending_review if percentile < 0.90
      return :rejected if percentile < 0.93
      return :paused if percentile < 0.95

      :sold
    end

    def published_at_for(status)
      case status
      when :published then @now - @rng.rand(0..60).days - @rng.rand(0..23).hours
      when :paused then @now - @rng.rand(25..60).days
      when :sold then @now - @rng.rand(3..40).days
      end
    end

    def labels_for(price, discounted, status)
      labels = [ price < 80_000 ? "value" : (price < 180_000 ? "mid_range" : "pro_gamer") ]
      labels << "deal" if discounted && chance(0.5)
      labels << "rare" if chance(0.04)
      labels << "free_shipping" if chance(0.12)
      labels << "featured" if status == :published && chance(0.06)
      labels.uniq
    end

    def listing_title(product, category)
      self.class.title_for(product, category)
    end

    def rounded_demo_price(cents)
      euros = (cents.to_f / 100).round
      euros = 1 if euros < 1

      case @rng.rand
      when 0.0...0.45
        euros = (euros - (euros % 10)) + 9
        euros = 9 if euros < 5
        euros * 100
      when 0.45...0.65
        [ ((euros / 5.0).round * 5), 5 ].max * 100
      when 0.65...0.82
        [ ((euros / 10.0).round * 10), 10 ].max * 100
      else
        (euros * 100) + 99
      end
    end

    def original_price_for(price_cents)
      original = rounded_demo_price(price_cents * (1.15 + (@rng.rand * 0.15)))
      original += 100 while original <= price_cents
      original
    end

    def listing_description(product, category, condition, specs, game_fps)
      paragraphs = []
      paragraphs << "#{product[:title]} en estado #{CONDITION_LABELS.fetch(condition.to_s)}. " \
                    "Se entrega tal y como se describe y ha sido probado antes de publicarlo."
      paragraphs << "Producto ideal para #{category.name.downcase}. Incluye todo lo que se " \
                    "detalla a continuación y se envía con embalaje protector."

      if specs.any?
        paragraphs << "Especificaciones principales:\n" +
                      specs.first(8).map { |key, value| spec_line(category, key, value) }.join("\n")
      end

      if game_fps.present?
        game_names = Game.active.pluck(:slug, :name).to_h
        lines = game_fps.filter_map do |slug, values|
          next if values.blank?

          name = game_names[slug] || slug.tr("-", " ").capitalize
          "En #{name} alcanza aproximadamente #{values['1080p']} FPS a 1080p, " \
            "#{values['1440p']} FPS a 1440p y #{values['4k']} FPS a 4K."
        end
        paragraphs << "Rendimiento estimado con la configuración indicada:\n#{lines.join("\n")}"
      end

      paragraphs << "Qué incluye:\n- Producto principal\n- Caja y accesorios originales " \
                    "(si se indican en las fotos)\n- Factura o justificante de compra cuando esté disponible"
      paragraphs << "Cualquier duda, escríbeme por el chat de PCMarket. Respondo rápido y " \
                    "puedo enviar más fotos o un vídeo funcionando."
      paragraphs.join("\n\n")
    end

    def spec_line(category, key, value)
      definition = effective_filters(category)[key]
      label = definition&.name("es") || key.to_s.tr("_", " ").capitalize
      options = definition ? definition.filter_options.index_by { |option| option.value.to_s } : {}
      values = Array(value).map { |item| options[item.to_s]&.label("es") || item.to_s }
      "- #{label}: #{values.join(', ')}"
    end

    def specs_for(category, product_specs)
      filters = effective_filters(category)
      specs = product_specs.stringify_keys.slice(*filters.keys)
      filters.each do |key, definition|
        next if specs[key].present?

        specs[key] = definition.filter_options.first&.value || "Other"
      end
      specs
    end

    def effective_filters(category)
      @effective_filters[category.id] ||= category.effective_filters.to_h do |definition|
        [ definition.key, definition ]
      end
    end

    def fps_table(gpu_model)
      return {} if gpu_model.blank?

      Game.active.pluck(:slug).index_with do |game_slug|
        PcFinder::Recommender::RESOLUTIONS.keys.index_with do |resolution|
          PcFinder::Recommender.estimate_fps(
            gpu_model: gpu_model, resolution: resolution, game_slug: game_slug
          ).round
        end
      end
    end

    def postal_code_for(seller)
      location = Catalog.locations.find { |city, region, _code| city == seller.city && region == seller.region&.name }
      location&.last || "28001"
    end

    def shipping_price(free_shipping)
      return 0 if free_shipping
      return 0 if chance(0.25)

      [ 395, 495, 595, 695 ].sample(random: @rng)
    end

    # ---------------------------------------------------------------- images

    def images_enabled?
      @images_enabled = images && Demo::ImageLibrary.manifest.any? if @images_enabled.nil?
      @images_enabled
    end

    def load_image_entries
      return [] unless images_enabled?

      Demo::ImageLibrary.manifest.filter_map do |entry|
        path = Demo::ImageLibrary.storage_root.join(entry["query_slug"], entry["file"])
        next unless path.file?

        blob = blob_for(path, entry)
        [ entry, blob ]
      end
    end

    def blob_for(path, entry)
      checksum = Digest::MD5.base64digest(path.binread)
      blob = ActiveStorage::Blob.find_by(checksum: checksum)
      blob ||= ActiveStorage::Blob.create_and_upload!(
        io: File.open(path),
        filename: entry["file"],
        content_type: "image/jpeg",
        metadata: {
          "demo" => true,
          "source" => entry["source"],
          "source_url" => entry["source_url"],
          "creator" => entry["creator"],
          "license" => entry["license"],
          "license_url" => entry["license_url"],
          "position" => entry["file"].to_s[/-(\d+)-/, 1].to_i
        }
      )
      blob.update!(
        metadata: blob.metadata.to_h.merge(
          "demo" => true, "source" => entry["source"],
          "source_url" => entry["source_url"], "creator" => entry["creator"],
          "license" => entry["license"], "license_url" => entry["license_url"],
          "position" => entry["file"].to_s[/-(\d+)-/, 1].to_i
        )
      )
      blob
    end

    def attach_listing_images(listing, category)
      return unless images_enabled?

      pool = image_pool_for(category.slug)
      return if pool.size < 2

      count = @rng.rand(2..6).clamp(2, pool.size)
      blobs = pool.sample(count, random: @rng).uniq
      now = Time.current
      rows = blobs.each_with_index.map do |blob, index|
        {
          record_type: "Listing", record_id: listing.id, name: "images",
          blob_id: blob.id, created_at: now + index.seconds
        }
      end
      ActiveStorage::Attachment.insert_all!(rows)
    end

    def image_pool_for(category_slug)
      entries = @image_entries.select do |entry, _blob|
        Array(entry["categories"]).include?(category_slug)
      end
      entries = @image_entries if entries.size < 3
      entries.map(&:last).uniq
    end

    def attach_store_branding(store, definition)
      return unless images_enabled?

      path = badge_file(initials_for(definition[:name]), definition[:colour],
                        "store-#{store.slug}")
      store.logo.attach(io: File.open(path), filename: "#{store.slug}-logo.png",
                        content_type: "image/png", metadata: { demo: true })
      banner = image_pool_for("desk-accessories").sample(random: @rng)
      store.banner.attach(banner) if banner
    end

    def attach_user_avatar(user, index)
      return unless images_enabled?

      colours = %w[#0f766e #4338ca #b45309 #be123c #0369a1 #7e22ce #15803d #c2410c]
      token = Digest::SHA1.hexdigest(user.email.to_s)[0, 12]
      path = badge_file(initials_for(user.full_name), colours[index % colours.size],
                        "avatar-#{token}", size: 192)
      user.avatar.attach(io: File.open(path), filename: "#{user.id}-avatar.png",
                         content_type: "image/png", metadata: { demo: true })
    end

    def initials_for(name)
      words = name.to_s.split(/\s+/).reject { |word| word.length < 2 }
      initials = words.first(2).map { |word| word[0].upcase }.join
      initials.presence || name.to_s[0, 2].upcase
    end

    def badge_file(initials, colour, slug, size: 256)
      path = Rails.root.join("storage/demo_generated", "#{slug}.png")
      return path if path.file?

      FileUtils.mkdir_p(path.dirname)
      svg = <<~SVG
        <svg xmlns="http://www.w3.org/2000/svg" width="#{size}" height="#{size}">
          <rect width="#{size}" height="#{size}" rx="#{size * 0.18}" fill="#{colour}"/>
          <text x="#{size / 2}" y="#{size * 0.62}" font-family="Arial, Helvetica, sans-serif"
                font-size="#{size * 0.34}" font-weight="700" text-anchor="middle"
                fill="#ffffff">#{ERB::Util.html_escape(initials)}</text>
        </svg>
      SVG
      begin
        Vips.block_untrusted(false)
        Vips::Image.new_from_buffer(svg, "").write_to_file(path.to_s)
      ensure
        Vips.block_untrusted(true)
      end
      path
    end

    # ------------------------------------------------------- social + offers

    def create_favorites_follows_and_searches
      visible_listings = @listings.select(&:published?)
      return if visible_listings.empty? || @buyers.empty?

      favorite_rows = {}
      scaled(1_500).times do
        buyer = @buyers.sample(random: @rng)
        listing = visible_listings.sample(random: @rng)
        next if listing.user_id == buyer.id

        favorite_rows[[ buyer.id, listing.id ]] ||= {
          user_id: buyer.id, listing_id: listing.id,
          created_at: @now - @rng.rand(0..45).days
        }
      end
      Favorite.insert_all!(favorite_rows.values) if favorite_rows.any?

      follow_rows = {}
      scaled(300).times do
        follower = @buyers.sample(random: @rng)
        store = @stores.sample(random: @rng)
        next if store.user_id == follower.id

        follow_rows[[ follower.id, store.id ]] ||= {
          follower_id: follower.id, store_id: store.id,
          created_at: @now - @rng.rand(0..90).days
        }
      end
      Follow.insert_all!(follow_rows.values) if follow_rows.any?

      search_rows = Array.new(scaled(80)) do |index|
        category = @leaf_categories.sample(random: @rng)
        SavedSearch.new(
          user: @buyers.sample(random: @rng),
          name: "Alerta #{index + 1}: #{category.name}",
          query: chance(0.4) ? category.name.split.first : nil,
          category_id: category.id,
          min_price_cents: chance(0.3) ? @rng.rand(1..20) * 5_000 : nil,
          max_price_cents: chance(0.5) ? @rng.rand(20..120) * 10_000 : nil,
          country_code: "ES",
          filters: { "_search" => { "category_id" => category.id } },
          notify: chance(0.85),
          frequency: chance(0.3) ? :daily : :instant,
          created_at: @now - @rng.rand(1..60).days,
          updated_at: @now - @rng.rand(1..60).days
        )
      end
      SavedSearch.insert_all!(search_rows.map(&:attributes).map { |attrs| attrs.except("id") })
    end

    def create_conversations
      target = scaled(120)
      created = 0
      attempts = 0
      visible = @listings.select(&:published?)
      return if visible.empty? || @buyers.empty?

      while created < target && attempts < target * 12
        attempts += 1
        listing = visible.sample(random: @rng)
        buyer = @buyers.sample(random: @rng)
        next if buyer.id == listing.user_id

        conversation = Conversation.new(
          listing: listing, buyer: buyer, seller: listing.user,
          created_at: @now - @rng.rand(1..50).days
        )
        next unless conversation.save

        create_messages(conversation, listing)
        created += 1
      end
    end

    def create_messages(conversation, listing)
      count = @rng.rand(2..6)
      start = conversation.created_at
      participants = [ conversation.buyer, conversation.seller ]
      last_message = nil

      count.times do |index|
        sender = participants[index % 2]
        at = start + (index * @rng.rand(10..90)).minutes
        flagged_body = chance(0.08) ? MESSAGE_BODIES.last(2).sample(random: @rng) : nil
        body = flagged_body || MESSAGE_BODIES.first(10).sample(random: @rng)

        if listing.accepts_offers? && index == 1 && chance(0.35)
          amount = (listing.price_cents * (0.72 + (@rng.rand * 0.2))).round
          last_message = Message.create!(
            conversation: conversation, sender: sender,
            body: "Te ofrezco #{amount / 100} € si me lo envías esta semana.",
            kind: :offer, offer_amount_cents: amount,
            offer_status: %i[pending accepted declined].sample(random: @rng),
            read_at: index < count - 1 ? at + 5.minutes : nil,
            created_at: at, updated_at: at
          )
        else
          last_message = Message.create!(
            conversation: conversation, sender: sender, body: body,
            read_at: index < count - 1 ? at + 5.minutes : nil,
            created_at: at, updated_at: at
          )
        end
      end

      conversation.update_columns(
        last_message_at: last_message.created_at,
        buyer_unread_count: last_message.sender_id == conversation.seller_id ? 1 : 0,
        seller_unread_count: last_message.sender_id == conversation.buyer_id ? 1 : 0
      )
    end

    # ---------------------------------------------------------------- orders

    def create_orders
      target = scaled(250)
      listings = @listings.select { |listing| listing.published? || listing.sold? }
      return if listings.empty? || @buyers.empty?

      target.times do |index|
        status = order_status_for(index, target)
        seller = @sellers.sample(random: @rng)
        seller_listings = listings.select { |listing| listing.user_id == seller.id }
        seller_listings = listings if seller_listings.empty?
        items = seller_listings.sample(@rng.rand(1..2), random: @rng)
        next if items.empty?

        buyer = @buyers.sample(random: @rng)
        next if buyer.id == seller.id

        order = create_order_record(status, seller, buyer, items)
        create_order_events(order, status)
      end
    end

    def order_status_for(index, total)
      percentile = index.to_f / total
      return :completed if percentile < 0.62
      return :delivered if percentile < 0.72
      return :shipped if percentile < 0.82
      return :paid if percentile < 0.90
      return :pending_payment if percentile < 0.95
      return :cancelled if percentile < 0.98
      return :refunded if percentile < 0.995

      :disputed
    end

    def create_order_record(status, seller, buyer, items)
      created_at = order_created_at(status)
      fulfilment = chance(0.2) ? :local_pickup : :shipping
      payment_method = if status == :pending_payment
        chance(0.7) ? "bank_transfer" : "stripe"
      elsif fulfilment == :local_pickup && chance(0.4)
        "cash_on_pickup"
      else
        chance(0.75) ? "stripe" : "bank_transfer"
      end
      subtotal = items.sum(&:price_cents)
      shipping = fulfilment == :shipping ? [ 0, 495, 695 ].sample(random: @rng) : 0
      timestamps = order_timestamps(status, created_at)
      guest_order = chance(0.05) && !%i[completed delivered].include?(status)

      order = Order.create!(
        buyer: guest_order ? nil : buyer,
        buyer_email: buyer.email,
        seller: seller,
        store: seller.store,
        status: :pending_payment,
        fulfilment: fulfilment,
        subtotal_cents: subtotal,
        shipping_cents: shipping,
        commission_cents: 0,
        total_cents: subtotal + shipping,
        currency: "EUR",
        payment_method: payment_method,
        payment_reference: status == :pending_payment ? nil : "DEMO-#{SecureRandom.hex(5).upcase}",
        locale: buyer.locale,
        checkout_token: SecureRandom.hex(12),
        terms_accepted_at: created_at,
        ship_name: buyer.full_name,
        ship_line1: "Calle Demo #{@rng.rand(1..120)}",
        ship_city: buyer.city,
        ship_postal_code: postal_code_for(buyer),
        ship_region: buyer.region&.name,
        ship_country_code: "ES",
        ship_phone: "+34600#{format('%06d', @rng.rand(0..999_999))}",
        created_at: created_at,
        updated_at: created_at
      )

      items.each do |listing|
        order.order_items.create!(
          listing: listing, title_snapshot: listing.title,
          price_cents: listing.price_cents, quantity: 1,
          created_at: created_at, updated_at: created_at
        )
      end

      order.update_columns(status: Order.statuses[status.to_s], **timestamps)
      order
    end

    def order_created_at(status)
      case status
      when :pending_payment then @now - @rng.rand(0..5).days
      when :paid then @now - @rng.rand(2..10).days
      when :shipped then @now - @rng.rand(4..18).days
      when :delivered then @now - @rng.rand(8..25).days
      when :completed then @now - @rng.rand(15..60).days
      when :cancelled then @now - @rng.rand(3..30).days
      when :refunded then @now - @rng.rand(10..50).days
      else @now - @rng.rand(6..20).days
      end
    end

    def order_timestamps(status, created_at)
      paid_at = created_at + 2.hours
      shipped_at = paid_at + 1.day
      delivered_at = shipped_at + 2.days
      completed_at = delivered_at + 2.days

      case status
      when :paid then { paid_at: paid_at }
      when :shipped then { paid_at: paid_at, shipped_at: shipped_at }
      when :delivered then { paid_at: paid_at, shipped_at: shipped_at, delivered_at: delivered_at }
      when :completed
        { paid_at: paid_at, shipped_at: shipped_at, delivered_at: delivered_at,
          completed_at: completed_at }
      when :cancelled then { cancelled_at: created_at + 1.day,
                             cancel_reason: "El comprador pidió cancelar el pedido." }
      when :refunded then { paid_at: paid_at, refunded_at: created_at + 5.days,
                            refund_reference: "REF-#{SecureRandom.hex(4).upcase}" }
      when :disputed
        { paid_at: paid_at, shipped_at: shipped_at,
          delivered_at: chance(0.5) ? delivered_at : nil, disputed_at: created_at + 3.days }
      else {}
      end.compact
    end

    def create_order_events(order, status)
      OrderEvent.where(order_id: order.id, kind: "placed")
                .update_all(created_at: order.created_at)
      rows = []
      paid = order.paid_at
      shipped = order.shipped_at

      rows << event_row(order, "paid", paid, order.seller_id) if paid
      rows << event_row(order, "shipped", shipped, order.seller_id) if shipped
      if order.delivered_at
        rows << event_row(order, "delivered", order.delivered_at, order.buyer_id)
      end
      if order.completed_at
        rows << event_row(order, "completed", order.completed_at, order.buyer_id)
      end
      if order.cancelled_at
        rows << event_row(order, "cancelled", order.cancelled_at, order.buyer_id,
                          { "reason" => order.cancel_reason })
      end
      if order.refunded_at
        rows << event_row(order, "refunded", order.refunded_at, @admin.id,
                          { "reference" => order.refund_reference })
      end
      if order.disputed_at
        rows << event_row(order, "dispute_opened", order.disputed_at, order.buyer_id,
                          { "reason" => Order::DISPUTE_REASONS.sample(random: @rng),
                            "details" => "El producto llegó con más marcas de las descritas." })
      end

      OrderEvent.insert_all!(rows.compact)
    end

    def event_row(order, kind, at, actor_id, data = {})
      return nil if at.blank?

      { order_id: order.id, actor_id: actor_id, kind: kind, data: data, created_at: at }
    end

    # --------------------------------------------------------------- reviews

    def create_reviews
      orders = Order.where(status: %i[completed delivered], buyer_id: @buyers.map(&:id))
                    .includes(:store).to_a
      return if orders.empty?

      rows = orders.sample([ scaled(180), orders.size ].min, random: @rng).map do |order|
        rating = weighted_rating
        reference = order.completed_at || order.delivered_at || order.shipped_at || order.created_at
        {
          order_id: order.id, reviewer_id: order.buyer_id, store_id: order.store_id,
          rating: rating,
          body: review_body(rating),
          seller_reply: chance(0.4) ? "Gracias por tu compra y por la reseña. ¡Disfrútalo!" : nil,
          published: true,
          created_at: [ reference + @rng.rand(0..20).days, @now ].min,
          updated_at: [ reference + @rng.rand(0..20).days, @now ].min
        }
      end
      Review.insert_all!(rows)
    end

    def weighted_rating
      pool = [ 5 ] * 55 + [ 4 ] * 30 + [ 3 ] * 9 + [ 2 ] * 4 + [ 1 ] * 2
      pool.sample(random: @rng)
    end

    def review_body(rating)
      case rating
      when 5
        "Todo perfecto: el producto llegó rápido, muy bien embalado y exactamente como " \
        "se describía. Vendedor muy recomendable, repetiré sin duda."
      when 4
        "Muy buena experiencia. El artículo está en el estado indicado y la comunicación " \
        "fue rápida, aunque el envío tardó un día más de lo previsto."
      when 3
        "El producto funciona correctamente, pero el embalaje podría haber sido mejor. " \
        "La descripción era bastante fiel."
      when 2
        "El artículo llegó con algunos arañazos que no aparecían en las fotos. El vendedor " \
        "respondió y llegamos a un acuerdo, pero la experiencia fue regular."
      else
        "La compra no salió como esperaba y tuve que abrir una incidencia. La comunicación " \
        "fue lenta durante varios días."
      end
    end

    # ----------------------------------- notifications, reports, marketing

    def create_notifications_reports_and_marketing
      create_notifications
      create_reports
      create_newsletter_subscribers
      create_feature_requests
      create_sell_offers
    end

    def create_notifications
      kinds = %w[message_received offer_received followed_store_listing saved_search_match
                 price_drop_favourite order_paid listing_approved]
      rows = Array.new(scaled(350)) do
        user = @buyers.sample(random: @rng)
        kind = kinds.sample(random: @rng)
        listing = @listings.sample(random: @rng)
        created_at = @now - @rng.rand(0..30).days
        {
          user_id: user.id, kind: kind,
          params: { sender: @sellers.sample(random: @rng).display_name,
                    listing: listing.title.truncate(60) },
          url: "/es/l/#{listing.slug}",
          read_at: chance(0.55) ? created_at + 1.day : nil,
          created_at: created_at, updated_at: created_at
        }
      end
      Notification.insert_all!(rows)
    end

    def create_reports
      reasons = Report.reasons.keys
      rows = {}
      scaled(15).times do
        listing = @listings.sample(random: @rng)
        reporter = @buyers.sample(random: @rng)
        next if listing.user_id == reporter.id

        rows[[ reporter.id, listing.id ]] ||= {
          reporter_id: reporter.id, reportable_type: "Listing", reportable_id: listing.id,
          reason: Report.reasons[reasons.sample(random: @rng)],
          details: "El anuncio parece sospechoso o no coincide con las fotos.",
          status: Report.statuses[:open],
          created_at: @now - @rng.rand(0..20).days,
          updated_at: @now - @rng.rand(0..20).days
        }
      end
      Report.insert_all!(rows.values) if rows.any?
    end

    def create_newsletter_subscribers
      rows = Array.new(scaled(200)) do |index|
        state = index % 10
        {
          email: "newsletter#{index + 1}@#{DEMO_DOMAIN}",
          locale: chance(0.2) ? "en" : "es",
          token: SecureRandom.hex(16),
          confirmed_at: state == 0 ? nil : @now - @rng.rand(1..90).days,
          unsubscribed_at: state == 1 ? @now - @rng.rand(1..30).days : nil,
          created_at: @now - @rng.rand(1..120).days,
          updated_at: @now - @rng.rand(1..120).days
        }
      end
      NewsletterSubscriber.insert_all!(rows)
    end

    def create_feature_requests
      listings = @listings.select(&:published?).sample([ scaled(4), 1 ].max, random: @rng)
      rows = listings.each_with_index.map do |listing, index|
        status = %i[pending paid active].sample(random: @rng)
        {
          listing_id: listing.id, user_id: listing.user_id, days: 7,
          price_cents: 4_900, status: FeatureRequest.statuses[status.to_s],
          paid_at: status == :pending ? nil : @now - @rng.rand(1..10).days,
          created_at: @now - @rng.rand(1..15).days,
          updated_at: @now - @rng.rand(0..10).days
        }
      end
      FeatureRequest.insert_all!(rows) if rows.any?
    end

    def create_sell_offers
      prices = BuybackPrice.active.order(:position).limit(4).to_a
      return if prices.empty?

      statuses = %i[offered accepted received paid]
      prices.each_with_index do |price, index|
        status = statuses[index] || :offered
        user = @buyers.sample(random: @rng)
        attributes = {
          user: user,
          buyback_price: price,
          item_kind: price.item_kind,
          item_name: price.item_model,
          condition: SellOffer::CONDITIONS.sample(random: @rng),
          offered_price_cents: (price.base_price_cents * 0.82).round,
          original_box: chance(0.5),
          accessories: "Cables originales",
          status: status,
          offer_expires_at: @now + 7.days,
          created_at: @now - @rng.rand(1..10).days
        }
        if %i[accepted received paid].include?(status)
          attributes.merge!(
            accepted_at: @now - 3.days,
            payout_iban: "ES9121000418450200051332",
            payout_account_name: user.full_name
          )
        end
        attributes[:received_at] = @now - 2.days if %i[received paid].include?(status)
        attributes[:paid_at] = @now - 1.day if status == :paid
        SellOffer.create!(attributes)
      end
    end

    # --------------------------------------------------------- counter caches

    def update_counter_caches
      connection = ActiveRecord::Base.connection
      connection.execute(<<~SQL)
        UPDATE listings
        SET favorites_count = (
          SELECT COUNT(*) FROM favorites WHERE favorites.listing_id = listings.id
        )
      SQL
      connection.execute(<<~SQL)
        UPDATE stores
        SET listings_count = (
              SELECT COUNT(*) FROM listings WHERE listings.store_id = stores.id
            ),
            followers_count = (
              SELECT COUNT(*) FROM follows WHERE follows.store_id = stores.id
            ),
            sales_count = (
              SELECT COUNT(*) FROM orders
              WHERE orders.store_id = stores.id AND orders.status = #{Order.statuses[:completed]}
            ),
            reviews_count = (
              SELECT COUNT(*) FROM reviews
              WHERE reviews.store_id = stores.id AND reviews.published = TRUE
            ),
            rating_avg = COALESCE((
              SELECT AVG(rating) FROM reviews
              WHERE reviews.store_id = stores.id AND reviews.published = TRUE
            ), 0)
      SQL
      connection.execute(<<~SQL)
        UPDATE categories
        SET listings_count = (
          SELECT COUNT(*) FROM listings WHERE listings.category_id = categories.id
        )
      SQL
    end

    # ---------------------------------------------------------------- summary

    def summary
      demo_user_ids = User.where("email LIKE ?", DEMO_EMAIL_PATTERN).pluck(:id)
      demo_listing_ids = Listing.where(user_id: demo_user_ids).pluck(:id)
      demo_order_ids = Order.where("buyer_id IN (?) OR seller_id IN (?)",
                                   demo_user_ids, demo_user_ids).pluck(:id)

      {
        "Demo users" => demo_user_ids.size,
        "Professional stores" => Store.where(user_id: demo_user_ids, store_type: :professional).count,
        "Individual sellers" => Store.where(user_id: demo_user_ids, store_type: :individual).count,
        "Buyers" => User.where("email LIKE ?", "buyer%@#{DEMO_DOMAIN}").count,
        "Listings" => demo_listing_ids.size,
        "Published listings" => Listing.where(id: demo_listing_ids, status: :published).count,
        "Listing images" => ActiveStorage::Attachment.where(record_type: "Listing",
                                                            record_id: demo_listing_ids).count,
        "Favourites" => Favorite.where(listing_id: demo_listing_ids).count,
        "Follows" => Follow.where(store_id: Store.where(user_id: demo_user_ids).select(:id)).count,
        "Saved searches" => SavedSearch.where(user_id: demo_user_ids).count,
        "Conversations" => Conversation.where("buyer_id IN (?) OR seller_id IN (?)",
                                              demo_user_ids, demo_user_ids).count,
        "Messages" => Message.joins(:conversation).where(
          conversations: { buyer_id: demo_user_ids }
        ).or(Message.joins(:conversation).where(conversations: { seller_id: demo_user_ids })).count,
        "Orders" => demo_order_ids.size,
        "Order events" => OrderEvent.where(order_id: demo_order_ids).count,
        "Reviews" => Review.where(order_id: demo_order_ids).count,
        "Notifications" => Notification.where(user_id: demo_user_ids).count,
        "Open reports" => Report.where(status: :open).count,
        "Newsletter subscribers" => NewsletterSubscriber.where("email LIKE ?", DEMO_EMAIL_PATTERN).count,
        "Feature requests" => FeatureRequest.where(user_id: demo_user_ids).count,
        "Sell offers" => SellOffer.where(user_id: demo_user_ids).count
      }
    end

    def print_summary(elapsed)
      puts "\nDemo seed complete in #{format('%.1f', elapsed)}s " \
           "(scale #{format('%.2f', scale)}, images #{images_enabled? ? 'on' : 'off'})"
      puts "-" * 48
      summary.each { |label, count| puts format("%-26s %6d", label, count) }
      puts "-" * 48
    end
  end
end
