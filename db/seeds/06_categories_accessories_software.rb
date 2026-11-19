# Children of "Accessories" and "Games & Software"
# (seed helpers in 03_categories_roots.rb).
accessories = [
  [ "art-decor", "Art & Decor", "Arte y decoración", "Art et décoration", "Kunst & Deko", "Arte e decor", "Arte e decoração",
    "Posters, prints, neon signs and desk art.",
    "Pósters, láminas, carteles de neón y arte de escritorio.",
    "Posters, tirages, néons et art de bureau.",
    "Poster, Prints, Neonschilder und Desk-Art.",
    "Poster, stampe, insegne al neon e arte da scrivania.",
    "Pósteres, impressões, néons e arte para secretária." ],
  [ "desk-accessories", "Desk Accessories", "Accesorios de escritorio", "Accessoires de bureau", "Schreibtisch-Zubehör", "Accessori da scrivania", "Acessórios de secretária",
    "Headphone stands, mats, cable management and lighting.",
    "Soportes para auriculares, alfombrillas, gestión de cables e iluminación.",
    "Supports casque, tapis, gestion des câbles et éclairage.",
    "Kopfhörer-Ständer, Mousepads, Kabelmanagement und Beleuchtung.",
    "Supporti per cuffie, tappetini, gestione dei cavi e illuminazione.",
    "Suportes para auscultadores, tapis, gestão de cabos e iluminação." ],
  [ "collectibles", "Collectibles", "Coleccionables", "Collectibles", "Kollektibles", "Collezionabili", "Colecionáveis",
    "Figures, retro boxes and limited-edition hardware.",
    "Figuras, cajas retro y hardware de edición limitada.",
    "Figurines, boîtes rétro et matériel en édition limitée.",
    "Figuren, Retro-Boxen und Hardware in limitierter Auflage.",
    "Figure, scatole retro e hardware in edizione limitata.",
    "Figuras, caixas retro e hardware de edição limitada." ],
  [ "clothing-gear", "Clothing & Gear", "Ropa y complementos", "Vêtements et accessoires", "Kleidung & Gear", "Abbigliamento e gadget", "Vestuário e acessórios",
    "T-shirts, hoodies, caps and community merch.",
    "Camisetas, sudaderas, gorras y merch de la comunidad.",
    "T-shirts, hoodies, casquettes et merch de la communauté.",
    "T-Shirts, Hoodies, Caps und Community-Merch.",
    "T-shirt, felpe, cappellini e merch della community.",
    "T-shirts, sweatshirts, bonés e merch da comunidade." ],
  [ "other-accessories", "Other Accessories", "Otros accesorios", "Autres accessoires", "Sonstiges Zubehör", "Altri accessori", "Outros acessórios",
    "Everything else a tech lover might want.",
    "Todo lo demás que un amante de la tecnología pueda desear.",
    "Tout ce qu'un passionné de tech peut souhaiter.",
    "Alles andere, was Tech-Fans sich wünschen.",
    "Tutto il resto che un amante della tecnologia può desiderare.",
    "Tudo o resto que um amante de tecnologia possa querer." ]
].freeze

accessories.each do |slug, *texts|
  names, descriptions = texts.each_slice(6).to_a
  seed_category slug, "accessory", "accessories", t6(*names), t6(*descriptions)
end

software = [
  [ "games", "Games", "Videojuegos", "Jeux vidéo", "Spiele", "Videogiochi", "Jogos",
    "Physical and digital games for PC and consoles.",
    "Juegos físicos y digitales para PC y consolas.",
    "Jeux physiques et numériques pour PC et consoles.",
    "Physische und digitale Spiele für PC und Konsolen.",
    "Giochi fisici e digitali per PC e console.",
    "Jogos físicos e digitais para PC e consolas." ],
  [ "software", "Software", "Software", "Logiciels", "Software", "Software", "Software",
    "Operating systems, productivity and creative licenses.",
    "Sistemas operativos, productividad y licencias creativas.",
    "Systèmes d'exploitation, productivité et licences créatives.",
    "Betriebssysteme, Produktivität und Creative-Lizenzen.",
    "Sistemi operativi, produttività e licenze creative.",
    "Sistemas operativos, produtividade e licenças criativas." ]
].freeze

software.each do |slug, *texts|
  names, descriptions = texts.each_slice(6).to_a
  seed_category slug, "software", "games-software", t6(*names), t6(*descriptions)
end
