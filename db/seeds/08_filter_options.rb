# Canonical values for every filter definition (boolean filters need none —
# they store "true"/"false" directly). Values are shown verbatim in the UI
# and matched exactly against listing specs, so keep them stable.

def seed_filter_option(key, display, numeric: nil, featured: false)
  definition = FilterDefinition.find_by!(key: key)
  seed_record(FilterOption, {
    filter_definition_id: definition.id,
    value: display.parameterize(separator: "-"),
    label_translations: LOCALIZED_LABELS.fetch(display) { same_translations(display) },
    numeric_value: numeric,
    featured: featured,
    active: true
  }, %i[filter_definition_id value])
end

# Options whose display text is a real word (not a brand or model name) get
# translated; the rest are identical in every locale.
LOCALIZED_LABELS = {
  "Other" => t6("Other", "Otro", "Autre", "Andere", "Altro", "Outro"),
  "Air" => t6("Air", "Aire", "Air", "Luft", "Aria", "Ar"),
  "AIO liquid" => t6("AIO liquid", "Líquida AIO", "Watercooling AIO", "AIO-Wasserkühlung", "A liquido AIO", "Líquido AIO"),
  "Custom loop" => t6("Custom loop", "Loop personalizado", "Boucle personnalisée", "Custom-Loop", "Loop personalizzato", "Loop personalizado"),
  "Black" => t6("Black", "Negro", "Noir", "Schwarz", "Nero", "Preto"),
  "White" => t6("White", "Blanco", "Blanc", "Weiß", "Bianco", "Branco"),
  "Gray" => t6("Gray", "Gris", "Gris", "Grau", "Grigio", "Cinzento"),
  "Silver" => t6("Silver", "Plateado", "Argent", "Silber", "Argento", "Prateado")
}.freeze

# A handful of options are marked "featured" so the sidebar can show a short
# list first (with a "show more" toggle).
FEATURED_OPTIONS = {
  "cpu_brand" => %w[Intel AMD],
  "cpu_core_count" => %w[6 8],
  "gpu_model" => [ "RTX 4060", "RTX 4070", "RX 7800 XT" ],
  "memory_capacity" => [ "16 GB", "32 GB" ],
  "monitor_refresh_rate" => [ "144 Hz", "165 Hz", "240 Hz" ],
  "psu_wattage" => [ "750W", "850W" ]
}.freeze

# Sort/numeric order for options that are really quantities.
NUMERIC_OPTIONS = {
  "cpu_core_count" => { "4" => 4, "6" => 6, "8" => 8, "12" => 12, "16" => 16, "24" => 24, "32" => 32 },
  "gpu_memory" => { "4 GB" => 4, "6 GB" => 6, "8 GB" => 8, "12 GB" => 12, "16 GB" => 16, "24 GB" => 24, "32 GB" => 32 },
  "memory_capacity" => { "8 GB" => 8, "16 GB" => 16, "32 GB" => 32, "64 GB" => 64, "128 GB" => 128 },
  "storage_capacity" => { "120 GB" => 120, "240 GB" => 240, "250 GB" => 250, "480 GB" => 480, "500 GB" => 500,
                          "1 TB" => 1_000, "2 TB" => 2_000, "4 TB" => 4_000, "8 TB" => 8_000 },
  "psu_wattage" => { "450W" => 450, "550W" => 550, "650W" => 650, "750W" => 750, "850W" => 850,
                     "1000W" => 1_000, "1200W" => 1_200, "1600W" => 1_600 },
  "monitor_refresh_rate" => { "60 Hz" => 60, "75 Hz" => 75, "100 Hz" => 100, "144 Hz" => 144, "165 Hz" => 165,
                              "180 Hz" => 180, "240 Hz" => 240, "360 Hz" => 360, "480 Hz" => 480 },
  "laptop_screen_size" => { "13.3\"" => 13.3, "14\"" => 14, "15.6\"" => 15.6, "16\"" => 16, "17.3\"" => 17.3, "18\"" => 18 },
  "monitor_size" => { "24\"" => 24, "27\"" => 27, "32\"" => 32, "34\"" => 34, "38\"" => 38, "49\"" => 49 }
}.freeze

# rubocop:disable Layout/LineLength, Style/WordArray
OPTIONS = {
  "cpu_brand" => %w[Intel AMD],
  "cpu_core_count" => %w[4 6 8 12 16 24 32],
  "cpu_socket" => [ "LGA 1700", "LGA 1851", "AM4", "AM5" ],
  "cpu_cooler_brand" => [ "Arctic", "be quiet!", "Cooler Master", "Corsair", "DeepCool", "Noctua", "Thermalright", "Thermaltake", "Other" ],
  "cpu_cooler_type" => [ "Air", "AIO liquid", "Custom loop" ],
  "gpu_chipset" => [ "NVIDIA", "AMD", "Intel" ],
  "gpu_model" => [ "RTX 3050", "RTX 3060", "RTX 3060 Ti", "RTX 3070", "RTX 3080", "RTX 4060", "RTX 4060 Ti",
                   "RTX 4070", "RTX 4070 Ti", "RTX 4080", "RTX 4090", "RX 6600", "RX 6650 XT", "RX 6700 XT",
                   "RX 7600", "RX 7700 XT", "RX 7800 XT", "RX 7900 XTX", "Arc A750", "Arc A770" ],
  "gpu_memory" => [ "4 GB", "6 GB", "8 GB", "12 GB", "16 GB", "24 GB", "32 GB" ],
  "memory_capacity" => [ "8 GB", "16 GB", "32 GB", "64 GB", "128 GB" ],
  "memory_brand" => [ "Corsair", "Crucial", "G.Skill", "Kingston", "Lexar", "Team Group", "Other" ],
  "memory_type" => %w[DDR3 DDR4 DDR5],
  "memory_form_factor" => %w[DIMM SO-DIMM],
  "storage_capacity" => [ "120 GB", "240 GB", "250 GB", "480 GB", "500 GB", "1 TB", "2 TB", "4 TB", "8 TB" ],
  "storage_interface" => [ "SATA III", "PCIe 3.0 NVMe", "PCIe 4.0 NVMe", "PCIe 5.0 NVMe" ],
  "storage_form_factor" => [ "2.5\"", "M.2 2230", "M.2 2280" ],
  "storage_brand" => [ "Crucial", "Kingston", "Lexar", "Samsung", "Seagate", "Western Digital", "Other" ],
  "motherboard_brand" => [ "ASRock", "ASUS", "Biostar", "Gigabyte", "MSI" ],
  "motherboard_form_factor" => %w[ATX Micro-ATX Mini-ITX E-ATX],
  "motherboard_networking" => [ "Wi-Fi 6", "Wi-Fi 6E", "Wi-Fi 7", "2.5G LAN", "10G LAN" ],
  "case_brand" => [ "be quiet!", "Corsair", "DeepCool", "Fractal Design", "Lian Li", "NZXT", "Phanteks", "Thermaltake", "Other" ],
  "case_form_factor" => [ "Full Tower", "Mid Tower", "Mini Tower", "Micro-ATX", "Mini-ITX/SFF" ],
  "case_color" => %w[Black White Gray Silver],
  "psu_brand" => [ "be quiet!", "Corsair", "Cooler Master", "DeepCool", "EVGA", "MSI", "Seasonic", "Thermaltake", "ASUS" ],
  "psu_wattage" => [ "450W", "550W", "650W", "750W", "850W", "1000W", "1200W", "1600W" ],
  "psu_form_factor" => %w[ATX SFX SFX-L],
  "laptop_screen_size" => [ "13.3\"", "14\"", "15.6\"", "16\"", "17.3\"", "18\"" ],
  "phone_brand" => [ "Apple", "Google", "Honor", "Huawei", "Motorola", "Nothing", "OnePlus", "Realme", "Samsung", "Xiaomi" ],
  "phone_storage" => [ "64 GB", "128 GB", "256 GB", "512 GB", "1 TB" ],
  "console_platform" => [ "PC", "PlayStation 4", "PlayStation 5", "Xbox One", "Xbox Series X|S", "Nintendo Switch", "Nintendo Switch 2" ],
  "monitor_size" => [ "24\"", "27\"", "32\"", "34\"", "38\"", "49\"" ],
  "monitor_resolution" => [ "1920x1080", "2560x1080", "2560x1440", "3440x1440", "3840x2160" ],
  "monitor_refresh_rate" => [ "60 Hz", "75 Hz", "100 Hz", "144 Hz", "165 Hz", "180 Hz", "240 Hz", "360 Hz", "480 Hz" ],
  "peripheral_brand" => [ "8BitDo", "Anker", "Apple", "ASUS", "Corsair", "Elgato", "Fanatec", "HyperX", "Keychron", "Logitech",
                          "Microsoft", "Moza", "Nintendo", "Other", "Razer", "Sony", "SteelSeries", "Thrustmaster", "Ugreen", "Zowie" ],
  "connectivity" => [ "Bluetooth", "DisplayPort", "Ethernet", "HDMI", "Thunderbolt", "USB", "USB-C", "Wi-Fi" ]
}.freeze
# rubocop:enable Layout/LineLength, Style/WordArray

OPTIONS.each do |key, values|
  numerics = NUMERIC_OPTIONS.fetch(key, {})
  featured = FEATURED_OPTIONS.fetch(key, [])
  values.each do |value|
    seed_filter_option(key, value, numeric: numerics[value], featured: featured.include?(value))
  end
end
