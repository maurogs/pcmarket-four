# Seeds are idempotent: running them repeatedly keeps existing records.
Setting.ensure_defaults!

COUNTRIES = [
  { code: "ES", name_key: "countries.ES", enabled: true, vat_rate: 21.0, default_locale: "es" },
  { code: "FR", name_key: "countries.FR", enabled: false, vat_rate: 20.0, default_locale: "fr" },
  { code: "DE", name_key: "countries.DE", enabled: false, vat_rate: 19.0, default_locale: "de" },
  { code: "IT", name_key: "countries.IT", enabled: false, vat_rate: 22.0, default_locale: "it" },
  { code: "PT", name_key: "countries.PT", enabled: false, vat_rate: 23.0, default_locale: "pt" },
  { code: "GB", name_key: "countries.GB", enabled: false, vat_rate: 20.0, default_locale: "en" }
].freeze

COUNTRIES.each do |attributes|
  country = Country.find_or_initialize_by(code: attributes[:code])
  country.assign_attributes(attributes.merge(currency: "EUR"))
  country.save!
end

REGIONS = {
  "ES" => [ "Comunidad de Madrid", "Cataluña", "Andalucía", "Comunidad Valenciana", "País Vasco" ],
  "FR" => [ "Île-de-France", "Occitanie" ],
  "DE" => [ "Berlín", "Baviera" ],
  "IT" => [ "Lazio", "Lombardía" ],
  "PT" => [ "Lisboa", "Porto" ],
  "GB" => [ "Greater London", "Greater Manchester" ]
}.freeze

REGIONS.each do |country_code, names|
  names.each do |name|
    Region.find_or_create_by!(country_code: country_code, name: name)
  end
end

def category_names(es:, en:, fr:, de:, it:, pt:)
  { "es" => es, "en" => en, "fr" => fr, "de" => de, "it" => it, "pt" => pt }
end

def seed_category(slug:, names:, position:, parent: nil, icon: nil, menu_group: nil, show_in_menu: true)
  category = Category.find_or_initialize_by(slug: slug)
  category.names = names
  category.position = position
  category.icon = icon
  category.menu_group = menu_group
  category.show_in_menu = show_in_menu
  category.active = true
  category.parent = parent if parent
  category.save!
  category
end

components = seed_category(
  slug: "components",
  names: category_names(es: "Componentes", en: "Components", fr: "Composants",
                        de: "Komponenten", it: "Componenti", pt: "Componentes"),
  position: 1, icon: "cpu-chip", menu_group: "hardware"
)
computers = seed_category(
  slug: "computers",
  names: category_names(es: "Ordenadores", en: "Computers", fr: "Ordinateurs",
                        de: "Computer", it: "Computer", pt: "Computadores"),
  position: 2, icon: "computer-desktop", menu_group: "computers"
)
peripherals = seed_category(
  slug: "peripherals",
  names: category_names(es: "Periféricos", en: "Peripherals", fr: "Périphériques",
                        de: "Peripheriegeräte", it: "Periferiche", pt: "Periféricos"),
  position: 3, icon: "keyboard", menu_group: "peripherals"
)
mobile = seed_category(
  slug: "mobile",
  names: category_names(es: "Móviles y tablets", en: "Phones and tablets", fr: "Téléphones et tablettes",
                        de: "Smartphones und Tablets", it: "Smartphone e tablet", pt: "Telemóveis e tablets"),
  position: 4, icon: "device-phone-mobile", menu_group: "mobile"
)
consoles = seed_category(
  slug: "consoles",
  names: category_names(es: "Consolas", en: "Consoles", fr: "Consoles",
                        de: "Konsolen", it: "Console", pt: "Consolas"),
  position: 5, icon: "puzzle-piece", menu_group: "gaming"
)

{
  graphics: {
      slug: "graphics-cards",
      names: category_names(es: "Tarjetas gráficas", en: "Graphics cards", fr: "Cartes graphiques",
                            de: "Grafikkarten", it: "Schede video", pt: "Placas gráficas"),
      position: 1, parent: components
    },
  processors: {
      slug: "processors",
      names: category_names(es: "Procesadores", en: "Processors", fr: "Processeurs",
                            de: "Prozessoren", it: "Processori", pt: "Processadores"),
      position: 2, parent: components
    },
  motherboards: {
      slug: "motherboards",
      names: category_names(es: "Placas base", en: "Motherboards", fr: "Cartes mères",
                            de: "Mainboards", it: "Schede madri", pt: "Placas-mãe"),
      position: 3, parent: components
    },
  memory: {
      slug: "memory",
      names: category_names(es: "Memoria RAM", en: "RAM memory", fr: "Mémoire RAM",
                            de: "Arbeitsspeicher", it: "Memoria RAM", pt: "Memória RAM"),
      position: 4, parent: components
    },
  storage: {
      slug: "storage",
      names: category_names(es: "Almacenamiento", en: "Storage", fr: "Stockage",
                            de: "Speicher", it: "Archiviazione", pt: "Armazenamento"),
      position: 5, parent: components
    },
  power_supplies: {
      slug: "power-supplies",
      names: category_names(es: "Fuentes de alimentación", en: "Power supplies", fr: "Alimentations",
                            de: "Netzteile", it: "Alimentatori", pt: "Fontes de alimentação"),
      position: 6, parent: components
    },
  prebuilt_pcs: {
      slug: "prebuilt-pcs",
      names: category_names(es: "Ordenadores montados", en: "Prebuilt PCs", fr: "PC assemblés",
                            de: "Komplett-PCs", it: "PC assemblati", pt: "Computadores montados"),
      position: 1, parent: computers
    },
  laptops: {
      slug: "laptops",
      names: category_names(es: "Portátiles", en: "Laptops", fr: "Ordinateurs portables",
                            de: "Laptops", it: "Portatili", pt: "Portáteis"),
      position: 2, parent: computers
    },
  monitors: {
      slug: "monitors",
      names: category_names(es: "Monitores", en: "Monitors", fr: "Écrans",
                            de: "Monitore", it: "Monitor", pt: "Monitores"),
      position: 1, parent: peripherals
    },
  keyboards: {
      slug: "keyboards",
      names: category_names(es: "Teclados", en: "Keyboards", fr: "Claviers",
                            de: "Tastaturen", it: "Tastiere", pt: "Teclados"),
      position: 2, parent: peripherals
    },
  mice: {
      slug: "mice",
      names: category_names(es: "Ratones", en: "Mice", fr: "Souris",
                            de: "Mäuse", it: "Mouse", pt: "Ratos"),
      position: 3, parent: peripherals
    },
  headsets: {
      slug: "headsets",
      names: category_names(es: "Auriculares", en: "Headsets", fr: "Casques",
                            de: "Headsets", it: "Cuffie", pt: "Auscultadores"),
      position: 4, parent: peripherals
    },
  phones: {
      slug: "phones",
      names: category_names(es: "Móviles", en: "Phones", fr: "Téléphones",
                            de: "Smartphones", it: "Smartphone", pt: "Telemóveis"),
      position: 1, parent: mobile
    },
  tablets: {
      slug: "tablets",
      names: category_names(es: "Tablets", en: "Tablets", fr: "Tablettes",
                            de: "Tablets", it: "Tablet", pt: "Tablets"),
      position: 2, parent: mobile
    },
  playstation: {
      slug: "playstation",
      names: category_names(es: "PlayStation", en: "PlayStation", fr: "PlayStation",
                            de: "PlayStation", it: "PlayStation", pt: "PlayStation"),
      position: 1, parent: consoles
    },
  xbox: {
      slug: "xbox",
      names: category_names(es: "Xbox", en: "Xbox", fr: "Xbox",
                            de: "Xbox", it: "Xbox", pt: "Xbox"),
      position: 2, parent: consoles
    },
  nintendo: {
      slug: "nintendo",
      names: category_names(es: "Nintendo", en: "Nintendo", fr: "Nintendo",
                            de: "Nintendo", it: "Nintendo", pt: "Nintendo"),
      position: 3, parent: consoles
  }
}.each_value { |attributes| seed_category(**attributes) }

FILTERS = {
  "cpu_brand" => {
    names: category_names(es: "Marca del procesador", en: "Processor brand", fr: "Marque du processeur",
                          de: "Prozessorhersteller", it: "Marca del processore", pt: "Marca do processador"),
    input_type: "select",
    position: 1
  },
  "gpu_brand" => {
    names: category_names(es: "Marca de la tarjeta", en: "Graphics card brand", fr: "Marque de la carte graphique",
                          de: "Grafikkartenhersteller", it: "Marca della scheda video", pt: "Marca da placa gráfica"),
    input_type: "select",
    position: 2
  },
  "vram" => {
    names: category_names(es: "Memoria gráfica", en: "Video memory", fr: "Mémoire vidéo",
                          de: "Videospeicher", it: "Memoria video", pt: "Memória gráfica"),
    input_type: "range",
    position: 3,
    unit: "GB"
  },
  "ram_size" => {
    names: category_names(es: "Memoria RAM", en: "RAM size", fr: "Taille de la RAM",
                          de: "Arbeitsspeicher", it: "Memoria RAM", pt: "Tamanho da RAM"),
    input_type: "range",
    position: 4,
    unit: "GB"
  },
  "storage_size" => {
    names: category_names(es: "Capacidad de almacenamiento", en: "Storage capacity", fr: "Capacité de stockage",
                          de: "Speicherkapazität", it: "Capacità di archiviazione", pt: "Capacidade de armazenamento"),
    input_type: "range",
    position: 5,
    unit: "GB"
  }
}.freeze

FILTERS.each do |key, attributes|
  filter = FilterDefinition.find_or_initialize_by(key: key)
  filter.assign_attributes(attributes.merge(active: true))
  filter.save!
end

FILTER_OPTIONS = {
  "cpu_brand" => %w[intel amd],
  "gpu_brand" => %w[nvidia amd intel]
}.freeze

FILTER_OPTIONS.each do |filter_key, values|
  filter = FilterDefinition.find_by!(key: filter_key)
  values.each_with_index do |value, index|
    option = FilterOption.find_or_initialize_by(filter_definition: filter, value: value)
    option.labels = category_names(
      es: value.upcase, en: value.upcase, fr: value.upcase,
      de: value.upcase, it: value.upcase, pt: value.upcase
    )
    option.position = index + 1
    option.save!
  end
end

CATEGORY_FILTERS = {
  "graphics-cards" => %w[gpu_brand vram],
  "processors" => %w[cpu_brand],
  "laptops" => %w[ram_size storage_size],
  "prebuilt-pcs" => %w[cpu_brand ram_size storage_size]
}.freeze

CATEGORY_FILTERS.each do |category_slug, filter_keys|
  category = Category.find_by!(slug: category_slug)
  filter_keys.each_with_index do |filter_key, index|
    filter = FilterDefinition.find_by!(key: filter_key)
    category_filter = CategoryFilter.find_or_initialize_by(category: category, filter_definition: filter)
    category_filter.position = index + 1
    category_filter.save!
  end
end

GAMES = [
  [ "fortnite", "Fortnite" ],
  [ "counter-strike-2", "Counter-Strike 2" ],
  [ "valorant", "Valorant" ],
  [ "league-of-legends", "League of Legends" ],
  [ "minecraft", "Minecraft" ],
  [ "cyberpunk-2077", "Cyberpunk 2077" ],
  [ "elden-ring", "Elden Ring" ],
  [ "call-of-duty-warzone", "Call of Duty: Warzone" ]
].freeze

GAMES.each_with_index do |(slug, name), index|
  game = Game.find_or_initialize_by(slug: slug)
  game.assign_attributes(name: name, position: index + 1, active: true)
  game.save!
end

TERMS_HTML = <<~HTML
  <h1>Términos y condiciones</h1>
  <p>PCMarket es un mercado de tecnología de segunda mano. Los vendedores son responsables de la exactitud de sus anuncios.</p>
HTML

LegalPage.find_or_create_by!(slug: "terms", country_code: "ES", locale: "es") do |page|
  page.title = "Términos y condiciones"
  page.body = TERMS_HTML
  page.version = 1
  page.published = true
end

LegalPage.find_or_create_by!(slug: "privacy", country_code: "ES", locale: "es") do |page|
  page.title = "Política de privacidad"
  page.body = "<h1>Política de privacidad</h1><p>Tratamos tus datos de acuerdo con el RGPD.</p>"
  page.version = 1
  page.published = true
end

unless Rails.env.production?
  admin = User.find_or_initialize_by(email: "admin@pcmarket.test")
  if admin.new_record?
    admin.assign_attributes(
      password: "Password123!",
      password_confirmation: "Password123!",
      first_name: "Ada",
      last_name: "Admin",
      username: "Admin-User#0001",
      role: :admin,
      status: :active,
      country_code: "ES",
      region: Region.find_by(country_code: "ES", name: "Comunidad de Madrid"),
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
        region: Region.find_by(country_code: "ES", name: "Comunidad de Madrid"),
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
      region: Region.find_by(country_code: "ES", name: "Comunidad de Madrid"),
      city: "Madrid"
    )
    store.save!

    unless seller.listings.exists?
      listing = seller.listings.new(
        store: store,
        category: Category.find_by!(slug: "graphics-cards"),
        title: "NVIDIA GeForce RTX 4070 Super 12 GB",
        description: "Tarjeta gráfica en perfecto estado, con caja original y todos los accesorios incluidos.",
        price_cents: 54_900,
        original_price_cents: 69_900,
        condition: :used_like_new,
        status: :published,
        published_at: Time.current,
        quantity: 1,
        brand: "NVIDIA",
        country_code: "ES",
        region: Region.find_by(country_code: "ES", name: "Comunidad de Madrid"),
        city: "Madrid",
        specs: { "cpu_brand" => "intel", "vram_gb" => 12 },
        accepts_offers: true
      )
      listing.save!
    end
  end
end

puts "Seeds ready: #{Country.count} countries, #{Category.count} categories, #{FilterDefinition.count} filters, #{Game.count} games."
