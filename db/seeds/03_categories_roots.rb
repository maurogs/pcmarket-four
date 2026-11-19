# Full marketplace category tree (roots here; children in 04–06). Order
# matters: parents are seeded before their children. Slugs are the canonical
# URLs (and match the header nav) — never change them once they are shared.
#
# "Value", "Mid-Range" and "Pro Gamer" are deliberately NOT categories: they
# are ProductLabels (see 09_labels_and_tags.rb).

# Builds the { "en" => …, "es" => …, "fr" => …, "de" => …, "it" => …, "pt" => … }
# hashes stored in the jsonb translation columns.
def t6(en, es, fr, de, it, pt)
  { "en" => en, "es" => es, "fr" => fr, "de" => de, "it" => it, "pt" => pt }
end

# Idempotent: matches on slug, inserts once, never rewrites admin edits.
# SEO copy is derived from the translated name/description (brand-suffixed
# title) so every locale ships fully localised meta tags from day one.
def seed_category(slug, kind, parent_slug, names, descriptions)
  record = Category.find_or_initialize_by(slug: slug)
  return record if record.persisted?

  record.update!(
    kind: kind,
    parent: parent_slug && Category.find_by!(slug: parent_slug),
    name_translations: names,
    description_translations: descriptions,
    seo_title_translations: names.transform_values { |name| "#{name} | PCMarket" },
    seo_description_translations: descriptions
  )
  record
end

seed_category "gaming-pcs", "full_system", nil,
  t6("Gaming PCs", "PC Gaming", "PC gamer", "Gaming-PCs", "PC gaming", "PCs gamer"),
  t6("Prebuilt and custom gaming desktops, from budget builds to full RTX rigs.",
     "PCs de sobremesa gaming prefabricados y a medida, desde presupuestos ajustados hasta equipos RTX completos.",
     "PC fixes de gaming prêts à l'emploi ou sur mesure, du budget serré à la config RTX complète.",
     "Fertige und selbst zusammengestellte Gaming-Desktops – vom Budget-Build bis zur kompletten RTX-Maschine.",
     "PC da gaming preassemblati e su misura, dalle configurazioni economiche ai full RTX.",
     "PCs de secretária gaming pré-montados e personalizados, desde opções económicas a equipas RTX completas.")

seed_category "workstations", "full_system", nil,
  t6("Workstations", "Estaciones de trabajo", "Stations de travail", "Workstations", "Workstation", "Estações de trabalho"),
  t6("High-performance machines for rendering, CAD, video editing and development.",
     "Equipos de alto rendimiento para render, CAD, edición de vídeo y programación.",
     "Machines hautes performances pour le rendu, la CAO, le montage vidéo et le développement.",
     "Leistungsstarke Rechner für Rendering, CAD, Videoschnitt und Entwicklung.",
     "Macchine ad alte prestazioni per rendering, CAD, montaggio video e sviluppo.",
     "Máquinas de alto desempenho para render, CAD, edição de vídeo e programação.")

seed_category "laptops", "mobile", nil,
  t6("Laptops", "Portátiles", "Ordinateurs portables", "Notebooks", "Portatili", "Portáteis"),
  t6("Gaming laptops, ultrabooks and everyday machines for work, study and play.",
     "Portátiles gaming, ultraportátiles y de uso diario para trabajar, estudiar y jugar.",
     "PC portables de gaming, ultrabooks et machines du quotidien pour travailler, étudier et jouer.",
     "Gaming-Notebooks, Ultrabooks und Alltags-Notebooks für Arbeit, Studium und Freizeit.",
     "Portatili da gaming, ultrabook e macchine di tutti i giorni per lavoro, studio e gioco.",
     "Portáteis gaming, ultraportáteis e máquinas de utilização diária para trabalhar, estudar e jogar.")

seed_category "phones", "mobile", nil,
  t6("Smartphones", "Smartphones", "Smartphones", "Smartphones", "Smartphone", "Smartphones"),
  t6("New and used phones, from flagships to reliable budget models.",
     "Móviles nuevos y de segunda mano, desde gama alta hasta modelos económicos de confianza.",
     "Téléphones neufs et d'occasion, des flagships aux modèles économiques fiables.",
     "Neue und gebrauchte Smartphones – vom Flaggschiff bis zum zuverlässigen Budget-Modell.",
     "Cellulari nuovi e usati, dai top di gamma ai modelli economici affidabili.",
     "Telemóveis novos e usados, desde topos de gama a modelos económicos fiáveis.")

seed_category "tablets", "mobile", nil,
  t6("Tablets", "Tablets", "Tablettes", "Tablets", "Tablet", "Tablets"),
  t6("Android, iPad and Windows tablets for media, notes and light work.",
     "Tablets Android, iPad y Windows para multimedia, notas y trabajo ligero.",
     "Tablettes Android, iPad et Windows pour le multimédia, la prise de notes et le travail léger.",
     "Android-, iPad- und Windows-Tablets für Medien, Notizen und leichte Arbeit.",
     "Tablet Android, iPad e Windows per multimedia, appunti e lavoro leggero.",
     "Tablets Android, iPad e Windows para multimédia, notas e trabalho ligeiro.")

seed_category "consoles", "gaming_system", nil,
  t6("Consoles", "Consolas", "Consoles", "Konsolen", "Console", "Consolas"),
  t6("PlayStation, Xbox and Nintendo consoles, bundles and special editions.",
     "Consolas PlayStation, Xbox y Nintendo, packs y ediciones especiales.",
     "Consoles PlayStation, Xbox et Nintendo, bundles et éditions spéciales.",
     "Konsolen von PlayStation, Xbox und Nintendo, Bundles und Special Editions.",
     "Console PlayStation, Xbox e Nintendo, bundle ed edizioni speciali.",
     "Consolas PlayStation, Xbox e Nintendo, packs e edições especiais.")

seed_category "gaming-handhelds", "gaming_system", nil,
  t6("Gaming Handhelds", "Consolas portátiles", "Consoles portables", "Handheld-Konsolen", "Console portatili", "Consolas portáteis"),
  t6("Steam Deck, ROG Ally, Switch and other PC handhelds for gaming on the go.",
     "Steam Deck, ROG Ally, Switch y demás consolas PC portátiles para jugar en cualquier sitio.",
     "Steam Deck, ROG Ally, Switch et autres consoles PC portables pour jouer partout.",
     "Steam Deck, ROG Ally, Switch und andere Handheld-PCs für Gaming unterwegs.",
     "Steam Deck, ROG Ally, Switch e altre console PC portatili per giocare ovunque.",
     "Steam Deck, ROG Ally, Switch e outras consolas PC portáteis para jogar em qualquer lado.")

seed_category "retro-consoles", "gaming_system", nil,
  t6("Retro Consoles", "Consolas retro", "Consoles rétro", "Retro-Konsolen", "Console retro", "Consolas retro"),
  t6("Classic consoles from N64 to PS2, tested and ready to play.",
     "Consolas clásicas desde la N64 hasta la PS2, probadas y listas para jugar.",
     "Consoles classiques de la N64 à la PS2, testées et prêtes à jouer.",
     "Klassische Konsolen von N64 bis PS2 – getestet und einsatzbereit.",
     "Console classiche dalla N64 alla PS2, testate e pronte all'uso.",
     "Consolas clássicas desde a N64 até à PS2, testadas e prontas a jogar.")

seed_category "retro-handhelds", "gaming_system", nil,
  t6("Retro Handhelds", "Consolas portátiles retro", "Consoles rétro portables", "Retro-Handhelds", "Console portatili retro", "Consolas portáteis retro"),
  t6("Game Boy, DS, PSP and modern emulation handhelds.",
     "Game Boy, DS, PSP y consolas de emulación modernas.",
     "Game Boy, DS, PSP et consoles d'émulation modernes.",
     "Game Boy, DS, PSP und moderne Emulations-Handhelds.",
     "Game Boy, DS, PSP e console di emulazione moderne.",
     "Game Boy, DS, PSP e consolas de emulação modernas.")

seed_category "components", "component", nil,
  t6("Components", "Componentes", "Composants", "Komponenten", "Componenti", "Componentes"),
  t6("GPUs, CPUs, motherboards, memory and every part for your build.",
     "Tarjetas gráficas, CPUs, placas base, memoria y cada pieza para tu montaje.",
     "Cartes graphiques, CPU, cartes mères, mémoire et toutes les pièces de votre configuration.",
     "Grafikkarten, CPUs, Mainboards, Arbeitsspeicher und jedes Bauteil für euren Build.",
     "Schede video, CPU, schede madri, memoria e ogni componente per il tuo build.",
     "Placas gráficas, CPUs, placas-mãe, memória e todas as peças para a sua montagem.")

seed_category "peripherals", "peripheral", nil,
  t6("Peripherals", "Periféricos", "Périphériques", "Peripherie", "Periferiche", "Periféricos"),
  t6("Monitors, keyboards, mice, audio and everything for your desk.",
     "Monitores, teclados, ratones, audio y todo para tu escritorio.",
     "Écrans, claviers, souris, audio et tout pour votre bureau.",
     "Monitore, Tastaturen, Mäuse, Audio und alles für den Schreibtisch.",
     "Monitor, tastiere, mouse, audio e tutto per la tua scrivania.",
     "Monitores, teclados, ratores, áudio e tudo para a sua secretária.")

seed_category "accessories", "accessory", nil,
  t6("Accessories", "Accesorios", "Accessoires", "Zubehör", "Accessori", "Acessórios"),
  t6("Art, desk gear, collectibles and apparel for tech lovers.",
     "Arte, complementos de escritorio, coleccionables y ropa para amantes de la tecnología.",
     "Déco, accessoires de bureau, collectors et vêtements pour passionnés de tech.",
     "Kunst, Desk-Zubehör, Sammlerstücke und Kleidung für Tech-Fans.",
     "Arte, accessori da scrivania, collezionabili e abbigliamento per gli amanti della tecnologia.",
     "Arte, acessórios de secretária, colecionáveis e vestuário para amantes de tecnologia.")

seed_category "games-software", "software", nil,
  t6("Games & Software", "Juegos y software", "Jeux et logiciels", "Spiele & Software", "Giochi e software", "Jogos e software"),
  t6("Physical and digital games plus operating systems and creative software.",
     "Juegos físicos y digitales, sistemas operativos y software creativo.",
     "Jeux physiques et numériques, systèmes d'exploitation et logiciels créatifs.",
     "Physische und digitale Spiele sowie Betriebssysteme und Creative-Software.",
     "Giochi fisici e digitali, sistemi operativi e software creativo.",
     "Jogos físicos e digitais, sistemas operativos e software criativo.")
