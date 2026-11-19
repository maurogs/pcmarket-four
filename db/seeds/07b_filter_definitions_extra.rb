# Filter definitions part 2/2 (motherboard → connectivity). Helpers and
# filter_group() live in 07_filter_definitions.rb.

definitions = [
  [ "motherboard_brand", "motherboard", t6("Brand", "Marca", "Marque", "Marke", "Marca", "Marca"), "multi_select" ],
  [ "motherboard_form_factor", "motherboard", t6("Form factor", "Formato", "Format", "Bauform", "Formato", "Formato"), "multi_select" ],
  [ "motherboard_networking", "motherboard", t6("Networking", "Conectividad", "Connectivité", "Netzwerk", "Rete", "Rede"), "multi_select" ],
  [ "case_brand", "case", t6("Brand", "Marca", "Marque", "Marke", "Marca", "Marca"), "multi_select" ],
  [ "case_form_factor", "case", t6("Case size", "Tamaño de caja", "Taille de boîtier", "Gehäusegröße", "Dimensione case", "Tamanho da caixa"), "multi_select" ],
  [ "case_color", "case", t6("Color", "Color", "Couleur", "Farbe", "Colore", "Cor"), "multi_select" ],
  [ "psu_brand", "power", t6("Brand", "Marca", "Marque", "Marke", "Marca", "Marca"), "multi_select" ],
  [ "psu_wattage", "power", t6("Wattage", "Potencia", "Puissance", "Wattage", "Potenza", "Potência"), "multi_select" ],
  [ "psu_form_factor", "power", t6("Form factor", "Formato", "Format", "Bauform", "Formato", "Formato"), "multi_select" ],
  [ "rgb_lighting", "features", t6("RGB lighting", "Iluminación RGB", "Éclairage RVB", "RGB-Beleuchtung", "Illuminazione RGB", "Iluminação RGB"), "boolean" ],
  [ "laptop_screen_size", "display", t6("Screen size", "Tamaño de pantalla", "Taille d'écran", "Bildschirmgröße", "Dimensione schermo", "Tamanho do ecrã"), "multi_select" ],
  [ "phone_brand", "device", t6("Brand", "Marca", "Marque", "Marke", "Marca", "Marca"), "multi_select" ],
  [ "phone_storage", "device", t6("Storage", "Almacenamiento", "Stockage", "Speicher", "Archiviazione", "Armazenamento"), "multi_select" ],
  [ "console_platform", "platform", t6("Platform", "Plataforma", "Plateforme", "Plattform", "Piattaforma", "Plataforma"), "single_select" ],
  [ "monitor_size", "display", t6("Diagonal", "Diagonal", "Diagonale", "Bildschirmdiagonale", "Diagonale", "Diagonal"), "multi_select" ],
  [ "monitor_resolution", "display", t6("Resolution", "Resolución", "Résolution", "Auflösung", "Risoluzione", "Resolução"), "multi_select" ],
  [ "monitor_refresh_rate", "display", t6("Refresh rate", "Tasa de refresco", "Taux de rafraîchissement", "Bildwiederholrate", "Frequenza di aggiornamento", "Taxa de atualização"), "multi_select" ],
  [ "peripheral_brand", "peripherals", t6("Brand", "Marca", "Marque", "Marke", "Marca", "Marca"), "multi_select" ],
  [ "connectivity", "connectivity", t6("Connectivity", "Conectividad", "Connectivité", "Konnektivität", "Connettività", "Conetividade"), "multi_select" ]
].freeze

definitions.each_with_index do |(key, group, label, input_type), index|
  seed_filter_definition(key, group, label, input_type, index + 17)
end
