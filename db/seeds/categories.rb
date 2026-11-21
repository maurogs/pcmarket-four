def category_names(es:, en:, fr:, de:, it:, pt:)
  { "es" => es, "en" => en, "fr" => fr, "de" => de, "it" => it, "pt" => pt }
end

def seed_category(slug:, names:, position:, parent: nil, icon: nil, menu_group: nil,
                  show_in_menu: false)
  category = Category.find_or_initialize_by(slug: slug)
  category.names = names
  category.position = position
  category.icon = icon
  category.menu_group = menu_group
  category.show_in_menu = show_in_menu
  category.active = true
  category.parent = parent
  category.save!
  category
end

root_categories = [
  {
    slug: "gaming-pcs", position: 1, icon: "gamepad-2", menu_group: "computers",
    names: category_names(es: "PC gaming", en: "Gaming PCs", fr: "PC gaming",
                          de: "Gaming-PCs", it: "PC gaming", pt: "PC gaming")
  },
  {
    slug: "workstations", position: 2, icon: "cpu", menu_group: "computers",
    names: category_names(es: "Estaciones de trabajo", en: "Workstations",
                          fr: "Stations de travail", de: "Workstations",
                          it: "Workstation", pt: "Estações de trabalho")
  },
  {
    slug: "laptops", position: 3, icon: "laptop", menu_group: "computers",
    names: category_names(es: "Portátiles", en: "Laptops", fr: "Ordinateurs portables",
                          de: "Laptops", it: "Portatili", pt: "Portáteis")
  },
  {
    slug: "phones", position: 4, icon: "smartphone", menu_group: "mobile",
    names: category_names(es: "Móviles", en: "Phones", fr: "Téléphones",
                          de: "Smartphones", it: "Smartphone", pt: "Telemóveis")
  },
  {
    slug: "tablets", position: 5, icon: "tablet", menu_group: "mobile",
    names: category_names(es: "Tablets", en: "Tablets", fr: "Tablettes",
                          de: "Tablets", it: "Tablet", pt: "Tablets")
  },
  {
    slug: "consoles-handhelds", position: 6, icon: "gamepad", menu_group: "gaming",
    names: category_names(es: "Consolas y portátiles", en: "Consoles & Handhelds",
                          fr: "Consoles et portables", de: "Konsolen & Handhelds",
                          it: "Console e handheld", pt: "Consolas e portáteis")
  },
  {
    slug: "components", position: 7, icon: "cpu", menu_group: "hardware",
    names: category_names(es: "Componentes", en: "Components", fr: "Composants",
                          de: "Komponenten", it: "Componenti", pt: "Componentes")
  },
  {
    slug: "peripherals", position: 8, icon: "keyboard", menu_group: "peripherals",
    names: category_names(es: "Periféricos", en: "Peripherals", fr: "Périphériques",
                          de: "Peripheriegeräte", it: "Periferiche", pt: "Periféricos")
  },
  {
    slug: "accessories", position: 9, icon: "gift", menu_group: "accessories",
    names: category_names(es: "Accesorios", en: "Accessories", fr: "Accessoires",
                          de: "Zubehör", it: "Accessori", pt: "Acessórios")
  },
  {
    slug: "games-software", position: 10, icon: "gamepad-2", menu_group: "software",
    names: category_names(es: "Juegos y software", en: "Games & Software",
                          fr: "Jeux et logiciels", de: "Spiele & Software",
                          it: "Giochi e software", pt: "Jogos e software")
  }
].freeze

child_categories = [
  # Workstations
  {
    slug: "creator-rigs", parent: "workstations", position: 1, icon: "video",
    names: category_names(es: "Equipos para creadores", en: "Creator Rigs",
                          fr: "Configurations créatives", de: "Creator-Rigs",
                          it: "Configurazioni per creator", pt: "Configurações para criadores")
  },
  {
    slug: "streaming-rigs", parent: "workstations", position: 2, icon: "radio",
    names: category_names(es: "Equipos para streaming", en: "Streaming Rigs",
                          fr: "Configurations streaming", de: "Streaming-Rigs",
                          it: "Configurazioni per streaming", pt: "Configurações para streaming")
  },
  {
    slug: "local-ai-rigs", parent: "workstations", position: 3, icon: "brain",
    names: category_names(es: "Equipos de IA local", en: "Local AI Rigs",
                          fr: "Configurations IA locale", de: "Lokale KI-Rigs",
                          it: "Configurazioni IA locale", pt: "Configurações de IA local")
  },

  # Laptops
  {
    slug: "gaming-laptops", parent: "laptops", position: 1, icon: "laptop",
    names: category_names(es: "Portátiles gaming", en: "Gaming Laptops",
                          fr: "PC portables gaming", de: "Gaming-Laptops",
                          it: "Portatili gaming", pt: "Portáteis gaming")
  },
  {
    slug: "ultrabooks", parent: "laptops", position: 2, icon: "laptop",
    names: category_names(es: "Ultrabooks", en: "Ultrabooks", fr: "Ultrabooks",
                          de: "Ultrabooks", it: "Ultrabook", pt: "Ultrabooks")
  },
  {
    slug: "macbooks", parent: "laptops", position: 3, icon: "laptop",
    names: category_names(es: "MacBook", en: "MacBooks", fr: "MacBook",
                          de: "MacBooks", it: "MacBook", pt: "MacBooks")
  },
  {
    slug: "other-laptops", parent: "laptops", position: 4, icon: "laptop",
    names: category_names(es: "Otros portátiles", en: "Other Laptops",
                          fr: "Autres ordinateurs portables", de: "Weitere Laptops",
                          it: "Altri portatili", pt: "Outros portáteis")
  },

  # Phones
  {
    slug: "iphone", parent: "phones", position: 1, icon: "smartphone",
    names: category_names(es: "iPhone", en: "iPhone", fr: "iPhone",
                          de: "iPhone", it: "iPhone", pt: "iPhone")
  },
  {
    slug: "android-phones", parent: "phones", position: 2, icon: "smartphone",
    names: category_names(es: "Móviles Android", en: "Android Phones",
                          fr: "Téléphones Android", de: "Android-Smartphones",
                          it: "Smartphone Android", pt: "Telemóveis Android")
  },
  {
    slug: "other-phones", parent: "phones", position: 3, icon: "smartphone",
    names: category_names(es: "Otros móviles", en: "Other Phones",
                          fr: "Autres téléphones", de: "Weitere Smartphones",
                          it: "Altri smartphone", pt: "Outros telemóveis")
  },

  # Tablets
  {
    slug: "ipad", parent: "tablets", position: 1, icon: "tablet",
    names: category_names(es: "iPad", en: "iPad", fr: "iPad",
                          de: "iPad", it: "iPad", pt: "iPad")
  },
  {
    slug: "android-tablets", parent: "tablets", position: 2, icon: "tablet",
    names: category_names(es: "Tablets Android", en: "Android Tablets",
                          fr: "Tablettes Android", de: "Android-Tablets",
                          it: "Tablet Android", pt: "Tablets Android")
  },
  {
    slug: "other-tablets", parent: "tablets", position: 3, icon: "tablet",
    names: category_names(es: "Otras tablets", en: "Other Tablets",
                          fr: "Autres tablettes", de: "Weitere Tablets",
                          it: "Altri tablet", pt: "Outros tablets")
  },

  # Consoles and handhelds
  {
    slug: "consoles", parent: "consoles-handhelds", position: 1, icon: "gamepad",
    names: category_names(es: "Consolas", en: "Consoles", fr: "Consoles",
                          de: "Konsolen", it: "Console", pt: "Consolas")
  },
  {
    slug: "handhelds", parent: "consoles-handhelds", position: 2, icon: "gamepad",
    names: category_names(es: "Consolas portátiles", en: "Handhelds",
                          fr: "Consoles portables", de: "Handhelds",
                          it: "Console portatili", pt: "Consolas portáteis")
  },
  {
    slug: "retro-consoles", parent: "consoles-handhelds", position: 3, icon: "gamepad",
    names: category_names(es: "Consolas retro", en: "Retro Consoles",
                          fr: "Consoles rétro", de: "Retro-Konsolen",
                          it: "Console retrò", pt: "Consolas retro")
  },
  {
    slug: "retro-handhelds", parent: "consoles-handhelds", position: 4, icon: "gamepad",
    names: category_names(es: "Portátiles retro", en: "Retro Handhelds",
                          fr: "Portables rétro", de: "Retro-Handhelds",
                          it: "Console portatili retrò", pt: "Portáteis retro")
  },
  {
    slug: "vr-headsets", parent: "consoles-handhelds", position: 5, icon: "glasses",
    names: category_names(es: "Gafas VR", en: "VR Headsets", fr: "Casques VR",
                          de: "VR-Headsets", it: "Visori VR", pt: "Headsets VR")
  },

  # Components
  {
    slug: "gpus", parent: "components", position: 1, icon: "monitor",
    names: category_names(es: "Tarjetas gráficas", en: "GPUs", fr: "Cartes graphiques",
                          de: "Grafikkarten", it: "Schede video", pt: "Placas gráficas")
  },
  {
    slug: "cpus", parent: "components", position: 2, icon: "cpu",
    names: category_names(es: "Procesadores", en: "CPUs", fr: "Processeurs",
                          de: "Prozessoren", it: "Processori", pt: "Processadores")
  },
  {
    slug: "cpu-coolers", parent: "components", position: 3, icon: "fan",
    names: category_names(es: "Disipadores de CPU", en: "CPU Coolers",
                          fr: "Ventilateurs CPU", de: "CPU-Kühler",
                          it: "Dissipatori CPU", pt: "Arrefecedores CPU")
  },
  {
    slug: "motherboards", parent: "components", position: 4, icon: "circuit-board",
    names: category_names(es: "Placas base", en: "Motherboards", fr: "Cartes mères",
                          de: "Mainboards", it: "Schede madri", pt: "Placas-mãe")
  },
  {
    slug: "motherboard-bundles", parent: "components", position: 5, icon: "package",
    names: category_names(es: "Packs de placa base", en: "Motherboard Bundles",
                          fr: "Packs carte mère", de: "Mainboard-Bundles",
                          it: "Bundle scheda madre", pt: "Pacotes de placa-mãe")
  },
  {
    slug: "memory", parent: "components", position: 6, icon: "memory-stick",
    names: category_names(es: "Memoria RAM", en: "Memory", fr: "Mémoire RAM",
                          de: "Arbeitsspeicher", it: "Memoria RAM", pt: "Memória RAM")
  },
  {
    slug: "storage", parent: "components", position: 7, icon: "hard-drive",
    names: category_names(es: "Almacenamiento", en: "Storage", fr: "Stockage",
                          de: "Speicher", it: "Archiviazione", pt: "Armazenamento")
  },
  {
    slug: "cases", parent: "components", position: 8, icon: "box",
    names: category_names(es: "Cajas", en: "Cases", fr: "Boîtiers",
                          de: "Gehäuse", it: "Case", pt: "Caixas")
  },
  {
    slug: "case-fans", parent: "components", position: 9, icon: "fan",
    names: category_names(es: "Ventiladores de caja", en: "Case Fans",
                          fr: "Ventilateurs de boîtier", de: "Gehäuselüfter",
                          it: "Ventole per case", pt: "Ventoinhas de caixa")
  },
  {
    slug: "power-supplies", parent: "components", position: 10, icon: "plug",
    names: category_names(es: "Fuentes de alimentación", en: "Power Supplies",
                          fr: "Alimentations", de: "Netzteile",
                          it: "Alimentatori", pt: "Fontes de alimentação")
  },
  {
    slug: "expansion-cards", parent: "components", position: 11, icon: "credit-card",
    names: category_names(es: "Tarjetas de expansión", en: "Expansion Cards",
                          fr: "Cartes d'extension", de: "Erweiterungskarten",
                          it: "Schede di espansione", pt: "Placas de expansão")
  },
  {
    slug: "network-adapters", parent: "components", position: 12, icon: "wifi",
    names: category_names(es: "Adaptadores de red", en: "Network Adapters",
                          fr: "Adaptateurs réseau", de: "Netzwerkadapter",
                          it: "Adattatori di rete", pt: "Adaptadores de rede")
  },
  {
    slug: "other-components", parent: "components", position: 13, icon: "package",
    names: category_names(es: "Otros componentes", en: "Other Components",
                          fr: "Autres composants", de: "Weitere Komponenten",
                          it: "Altri componenti", pt: "Outros componentes")
  },

  # Peripherals
  {
    slug: "monitors", parent: "peripherals", position: 1, icon: "monitor",
    names: category_names(es: "Monitores", en: "Monitors", fr: "Écrans",
                          de: "Monitore", it: "Monitor", pt: "Monitores")
  },
  {
    slug: "headphones", parent: "peripherals", position: 2, icon: "headphones",
    names: category_names(es: "Auriculares", en: "Headphones", fr: "Casques",
                          de: "Kopfhörer", it: "Cuffie", pt: "Auscultadores")
  },
  {
    slug: "keyboards", parent: "peripherals", position: 3, icon: "keyboard",
    names: category_names(es: "Teclados", en: "Keyboards", fr: "Claviers",
                          de: "Tastaturen", it: "Tastiere", pt: "Teclados")
  },
  {
    slug: "mice", parent: "peripherals", position: 4, icon: "mouse",
    names: category_names(es: "Ratones", en: "Mice", fr: "Souris",
                          de: "Mäuse", it: "Mouse", pt: "Ratos")
  },
  {
    slug: "speakers", parent: "peripherals", position: 5, icon: "speaker",
    names: category_names(es: "Altavoces", en: "Speakers", fr: "Enceintes",
                          de: "Lautsprecher", it: "Diffusori", pt: "Altifalantes")
  },
  {
    slug: "controllers", parent: "peripherals", position: 6, icon: "gamepad",
    names: category_names(es: "Mandos", en: "Controllers", fr: "Manettes",
                          de: "Controller", it: "Controller", pt: "Comandos")
  },
  {
    slug: "retro-controllers", parent: "peripherals", position: 7, icon: "gamepad-2",
    names: category_names(es: "Mandos retro", en: "Retro Controllers",
                          fr: "Manettes rétro", de: "Retro-Controller",
                          it: "Controller retrò", pt: "Comandos retro")
  },
  {
    slug: "sim-racing", parent: "peripherals", position: 8, icon: "steering-wheel",
    names: category_names(es: "Sim racing", en: "Sim Racing", fr: "Sim racing",
                          de: "Sim-Racing", it: "Sim racing", pt: "Sim racing")
  },
  {
    slug: "webcams", parent: "peripherals", position: 9, icon: "webcam",
    names: category_names(es: "Cámaras web", en: "Webcams", fr: "Webcams",
                          de: "Webcams", it: "Webcam", pt: "Webcams")
  },
  {
    slug: "microphones", parent: "peripherals", position: 10, icon: "mic",
    names: category_names(es: "Micrófonos", en: "Microphones", fr: "Microphones",
                          de: "Mikrofone", it: "Microfoni", pt: "Microfones")
  },
  {
    slug: "external-storage", parent: "peripherals", position: 11, icon: "hard-drive",
    names: category_names(es: "Almacenamiento externo", en: "External Storage",
                          fr: "Stockage externe", de: "Externer Speicher",
                          it: "Archiviazione esterna", pt: "Armazenamento externo")
  },
  {
    slug: "other-peripherals", parent: "peripherals", position: 12, icon: "package",
    names: category_names(es: "Otros periféricos", en: "Other Peripherals",
                          fr: "Autres périphériques", de: "Weitere Peripheriegeräte",
                          it: "Altre periferiche", pt: "Outros periféricos")
  },

  # Accessories
  {
    slug: "desk-accessories", parent: "accessories", position: 1, icon: "lamp-desk",
    names: category_names(es: "Accesorios de escritorio", en: "Desk Accessories",
                          fr: "Accessoires de bureau", de: "Schreibtischzubehör",
                          it: "Accessori da scrivania", pt: "Acessórios de secretária")
  },
  {
    slug: "art-decor", parent: "accessories", position: 2, icon: "image",
    names: category_names(es: "Arte y decoración", en: "Art & Decor",
                          fr: "Art et décoration", de: "Kunst & Deko",
                          it: "Arte e decorazione", pt: "Arte e decoração")
  },
  {
    slug: "collectibles", parent: "accessories", position: 3, icon: "gem",
    names: category_names(es: "Coleccionables", en: "Collectibles",
                          fr: "Objets de collection", de: "Sammlerstücke",
                          it: "Da collezione", pt: "Colecionáveis")
  },
  {
    slug: "clothing-gear", parent: "accessories", position: 4, icon: "shirt",
    names: category_names(es: "Ropa y equipación", en: "Clothing & Gear",
                          fr: "Vêtements et équipement", de: "Bekleidung & Ausrüstung",
                          it: "Abbigliamento e attrezzatura", pt: "Vestuário e equipamento")
  },
  {
    slug: "other-accessories", parent: "accessories", position: 5, icon: "package",
    names: category_names(es: "Otros accesorios", en: "Other Accessories",
                          fr: "Autres accessoires", de: "Weiteres Zubehör",
                          it: "Altri accessori", pt: "Outros acessórios")
  },

  # Games and software
  {
    slug: "games", parent: "games-software", position: 1, icon: "gamepad-2",
    names: category_names(es: "Juegos", en: "Games", fr: "Jeux",
                          de: "Spiele", it: "Giochi", pt: "Jogos")
  },
  {
    slug: "software", parent: "games-software", position: 2, icon: "app-window",
    names: category_names(es: "Software", en: "Software", fr: "Logiciels",
                          de: "Software", it: "Software", pt: "Software")
  }
].freeze

categories_by_slug = {}

root_categories.each do |attributes|
  categories_by_slug[attributes[:slug]] = seed_category(**attributes, show_in_menu: true)
end

child_categories.each do |attributes|
  parent = categories_by_slug.fetch(attributes[:parent])
  categories_by_slug[attributes[:slug]] = seed_category(
    **attributes, parent: parent, menu_group: parent.menu_group, show_in_menu: false
  )
end

# Remove categories created by the Phase 1 seed that are no longer part of the
# taxonomy. Categories that still own listings are preserved to avoid data loss.
legacy_category_slugs = %w[
  computers prebuilt-pcs graphics-cards processors headsets mobile playstation xbox nintendo
].freeze

legacy_category_slugs.each do |slug|
  category = Category.find_by(slug: slug)
  next if category.nil?
  next if category.listings.exists?
  next if category.descendants.joins(:listings).exists?

  category.destroy
end
