module Demo
  # Realistic Spanish product catalogue used by the demo seeder. Prices are
  # typical second-hand marketplace prices in cents, not retail RRP.
  module Catalog
    LOCATIONS = [
      [ "Madrid", "Madrid", "28001" ], [ "Barcelona", "Barcelona", "08001" ],
      [ "Valencia", "Valencia", "46001" ], [ "Sevilla", "Sevilla", "41001" ],
      [ "Bilbao", "Bizkaia", "48001" ], [ "Málaga", "Málaga", "29001" ],
      [ "Zaragoza", "Zaragoza", "50001" ], [ "A Coruña", "A Coruña", "15001" ],
      [ "Murcia", "Murcia", "30001" ], [ "Las Palmas de Gran Canaria", "Las Palmas", "35001" ],
      [ "Valladolid", "Valladolid", "47001" ], [ "Alicante", "Alicante", "03001" ],
      [ "Granada", "Granada", "18001" ], [ "Palma", "Illes Balears", "07001" ],
      [ "Santa Cruz de Tenerife", "Santa Cruz de Tenerife", "38001" ],
      [ "Pamplona", "Navarra", "31001" ], [ "Salamanca", "Salamanca", "37001" ],
      [ "Santander", "Cantabria", "39001" ], [ "Oviedo", "Asturias", "33001" ],
      [ "Lleida", "Lleida", "25001" ], [ "Tarragona", "Tarragona", "43001" ],
      [ "Córdoba", "Córdoba", "14001" ], [ "Toledo", "Toledo", "45001" ],
      [ "Badajoz", "Badajoz", "06001" ], [ "Logroño", "La Rioja", "26001" ]
    ].freeze

    STORE_DEFINITIONS = [
      { name: "Bits & Bytes Valencia", company: "Bits & Bytes Valencia S.L.",
        city: "Valencia", region: "Valencia", colour: "#0f766e" },
      { name: "Rig Factory Madrid", company: "Rig Factory Madrid S.L.",
        city: "Madrid", region: "Madrid", colour: "#4338ca" },
      { name: "TecnoNorte Bilbao", company: "TecnoNorte Bilbao S.L.",
        city: "Bilbao", region: "Bizkaia", colour: "#b45309" },
      { name: "PixelHouse Barcelona", company: "PixelHouse Barcelona S.L.",
        city: "Barcelona", region: "Barcelona", colour: "#be123c" },
      { name: "Overclock Sevilla", company: "Overclock Sevilla S.L.",
        city: "Sevilla", region: "Sevilla", colour: "#0369a1" },
      { name: "Nébula Gaming Málaga", company: "Nebula Gaming Malaga S.L.",
        city: "Málaga", region: "Málaga", colour: "#7e22ce" },
      { name: "CompuZaragoza", company: "CompuZaragoza S.L.",
        city: "Zaragoza", region: "Zaragoza", colour: "#15803d" },
      { name: "Galicia Hardware", company: "Galicia Hardware S.L.",
        city: "A Coruña", region: "A Coruña", colour: "#1d4ed8" },
      { name: "Murcia Tech Lab", company: "Murcia Tech Lab S.L.",
        city: "Murcia", region: "Murcia", colour: "#c2410c" },
      { name: "Isla Componentes", company: "Isla Componentes S.L.",
        city: "Las Palmas de Gran Canaria", region: "Las Palmas", colour: "#0e7490" },
      { name: "Norte Gamer Valladolid", company: "Norte Gamer Valladolid S.L.",
        city: "Valladolid", region: "Valladolid", colour: "#4d7c0f" },
      { name: "Alicante PC Store", company: "Alicante PC Store S.L.",
        city: "Alicante", region: "Alicante", colour: "#9f1239" }
    ].freeze

    CATEGORY_WEIGHTS = {
      "gaming-pcs" => 70, "creator-rigs" => 8, "streaming-rigs" => 6, "local-ai-rigs" => 5,
      "gaming-laptops" => 25, "ultrabooks" => 15, "macbooks" => 18, "other-laptops" => 5,
      "iphone" => 18, "android-phones" => 15, "other-phones" => 4,
      "ipad" => 10, "android-tablets" => 6, "other-tablets" => 3,
      "consoles" => 16, "handhelds" => 8, "retro-consoles" => 8,
      "retro-handhelds" => 4, "vr-headsets" => 8,
      "gpus" => 55, "cpus" => 30, "cpu-coolers" => 18, "motherboards" => 22,
      "motherboard-bundles" => 5, "memory" => 30, "storage" => 30, "cases" => 22,
      "case-fans" => 8, "power-supplies" => 18, "expansion-cards" => 4,
      "network-adapters" => 4, "other-components" => 5,
      "monitors" => 28, "headphones" => 20, "keyboards" => 26, "mice" => 26,
      "speakers" => 6, "controllers" => 14, "retro-controllers" => 4, "sim-racing" => 5,
      "webcams" => 8, "microphones" => 10, "external-storage" => 10,
      "other-peripherals" => 5,
      "desk-accessories" => 3, "art-decor" => 3, "collectibles" => 3,
      "clothing-gear" => 3, "other-accessories" => 3,
      "games" => 8, "software" => 4
    }.freeze

    CONDITION_MULTIPLIERS = {
      "new_sealed" => 1.25, "new_open_box" => 1.12, "used_like_new" => 1.0,
      "used_good" => 0.86, "used_fair" => 0.72, "for_parts" => 0.45
    }.freeze

    GPUS = [
      { model: "RTX 5090", brand: "NVIDIA", label: "NVIDIA GeForce RTX 5090 32 GB",
        chipset: "NVIDIA", memory: "32GB", price: 199_000, tier: 100 },
      { model: "RTX 5080", brand: "NVIDIA", label: "NVIDIA GeForce RTX 5080 16 GB",
        chipset: "NVIDIA", memory: "16GB", price: 119_000, tier: 94 },
      { model: "RTX 5070 Ti", brand: "NVIDIA", label: "NVIDIA GeForce RTX 5070 Ti 16 GB",
        chipset: "NVIDIA", memory: "16GB", price: 84_900, tier: 88 },
      { model: "RTX 5070", brand: "NVIDIA", label: "NVIDIA GeForce RTX 5070 12 GB",
        chipset: "NVIDIA", memory: "12GB", price: 59_900, tier: 82 },
      { model: "RTX 5060 Ti", brand: "NVIDIA", label: "NVIDIA GeForce RTX 5060 Ti 16 GB",
        chipset: "NVIDIA", memory: "16GB", price: 42_900, tier: 72 },
      { model: "RTX 5060", brand: "NVIDIA", label: "NVIDIA GeForce RTX 5060 8 GB",
        chipset: "NVIDIA", memory: "8GB", price: 32_900, tier: 64 },
      { model: "RTX 4090", brand: "NVIDIA", label: "NVIDIA GeForce RTX 4090 24 GB",
        chipset: "NVIDIA", memory: "24GB", price: 149_000, tier: 96 },
      { model: "RTX 4080", brand: "NVIDIA", label: "NVIDIA GeForce RTX 4080 16 GB",
        chipset: "NVIDIA", memory: "16GB", price: 99_900, tier: 90 },
      { model: "RTX 4070 Ti", brand: "NVIDIA", label: "NVIDIA GeForce RTX 4070 Ti 12 GB",
        chipset: "NVIDIA", memory: "12GB", price: 74_900, tier: 84 },
      { model: "RTX 4070", brand: "NVIDIA", label: "NVIDIA GeForce RTX 4070 12 GB",
        chipset: "NVIDIA", memory: "12GB", price: 54_900, tier: 76 },
      { model: "RTX 4060 Ti", brand: "NVIDIA", label: "NVIDIA GeForce RTX 4060 Ti 8 GB",
        chipset: "NVIDIA", memory: "8GB", price: 37_900, tier: 66 },
      { model: "RTX 4060", brand: "NVIDIA", label: "NVIDIA GeForce RTX 4060 8 GB",
        chipset: "NVIDIA", memory: "8GB", price: 28_900, tier: 58 },
      { model: "RTX 3090", brand: "NVIDIA", label: "NVIDIA GeForce RTX 3090 24 GB",
        chipset: "NVIDIA", memory: "24GB", price: 69_900, tier: 88 },
      { model: "RTX 3080", brand: "NVIDIA", label: "NVIDIA GeForce RTX 3080 10 GB",
        chipset: "NVIDIA", memory: "10GB", price: 44_900, tier: 80 },
      { model: "RTX 3070", brand: "NVIDIA", label: "NVIDIA GeForce RTX 3070 8 GB",
        chipset: "NVIDIA", memory: "8GB", price: 32_900, tier: 70 },
      { model: "RTX 3060", brand: "NVIDIA", label: "NVIDIA GeForce RTX 3060 12 GB",
        chipset: "NVIDIA", memory: "12GB", price: 24_900, tier: 52 },
      { model: "RX 9070 XT", brand: "AMD", label: "AMD Radeon RX 9070 XT 16 GB",
        chipset: "AMD", memory: "16GB", price: 69_900, tier: 88 },
      { model: "RX 9070", brand: "AMD", label: "AMD Radeon RX 9070 16 GB",
        chipset: "AMD", memory: "16GB", price: 59_900, tier: 84 },
      { model: "RX 7900 XTX", brand: "AMD", label: "AMD Radeon RX 7900 XTX 24 GB",
        chipset: "AMD", memory: "24GB", price: 84_900, tier: 90 },
      { model: "RX 7900 XT", brand: "AMD", label: "AMD Radeon RX 7900 XT 20 GB",
        chipset: "AMD", memory: "20GB", price: 69_900, tier: 86 },
      { model: "RX 7800 XT", brand: "AMD", label: "AMD Radeon RX 7800 XT 16 GB",
        chipset: "AMD", memory: "16GB", price: 49_900, tier: 78 },
      { model: "RX 7700 XT", brand: "AMD", label: "AMD Radeon RX 7700 XT 12 GB",
        chipset: "AMD", memory: "12GB", price: 39_900, tier: 72 },
      { model: "RX 7600", brand: "AMD", label: "AMD Radeon RX 7600 8 GB",
        chipset: "AMD", memory: "8GB", price: 24_900, tier: 60 },
      { model: "RX 6800 XT", brand: "AMD", label: "AMD Radeon RX 6800 XT 16 GB",
        chipset: "AMD", memory: "16GB", price: 39_900, tier: 74 },
      { model: "RX 6700 XT", brand: "AMD", label: "AMD Radeon RX 6700 XT 12 GB",
        chipset: "AMD", memory: "12GB", price: 27_900, tier: 64 },
      { model: "RX 6600", brand: "AMD", label: "AMD Radeon RX 6600 8 GB",
        chipset: "AMD", memory: "8GB", price: 16_900, tier: 35 },
      { model: "Arc B580", brand: "Intel", label: "Intel Arc B580 12 GB",
        chipset: "Intel", memory: "12GB", price: 26_900, tier: 58 },
      { model: "Arc A770", brand: "Intel", label: "Intel Arc A770 16 GB",
        chipset: "Intel", memory: "16GB", price: 22_900, tier: 55 }
    ].freeze

    CPUS = [
      { name: "Ryzen 9 9950X", brand: "AMD", cores: "16", socket: "AM5", price: 54_900 },
      { name: "Ryzen 9 9900X", brand: "AMD", cores: "12", socket: "AM5", price: 44_900 },
      { name: "Ryzen 7 9800X3D", brand: "AMD", cores: "8", socket: "AM5", price: 47_900 },
      { name: "Ryzen 7 9700X", brand: "AMD", cores: "8", socket: "AM5", price: 32_900 },
      { name: "Ryzen 7 7800X3D", brand: "AMD", cores: "8", socket: "AM5", price: 34_900 },
      { name: "Ryzen 5 7600X", brand: "AMD", cores: "6", socket: "AM5", price: 19_900 },
      { name: "Ryzen 7 5800X3D", brand: "AMD", cores: "8", socket: "AM4", price: 24_900 },
      { name: "Ryzen 5 5600", brand: "AMD", cores: "6", socket: "AM4", price: 9_900 },
      { name: "Core i9-14900K", brand: "Intel", cores: "24", socket: "LGA 1700", price: 49_900 },
      { name: "Core i7-14700K", brand: "Intel", cores: "20", socket: "LGA 1700", price: 37_900 },
      { name: "Core i5-14600K", brand: "Intel", cores: "14", socket: "LGA 1700", price: 24_900 },
      { name: "Core i5-13600K", brand: "Intel", cores: "14", socket: "LGA 1700", price: 19_900 },
      { name: "Core i9-13900K", brand: "Intel", cores: "24", socket: "LGA 1700", price: 39_900 },
      { name: "Core i7-13700K", brand: "Intel", cores: "16", socket: "LGA 1700", price: 27_900 },
      { name: "Core i5-12400F", brand: "Intel", cores: "6", socket: "LGA 1700", price: 10_900 },
      { name: "Core Ultra 9 285K", brand: "Intel", cores: "24", socket: "LGA 1851", price: 54_900 },
      { name: "Core Ultra 7 265K", brand: "Intel", cores: "20", socket: "LGA 1851", price: 39_900 }
    ].freeze

    RAMS = [
      { title: "Corsair Vengeance DDR5 32 GB (2×16 GB) 6000 MHz CL30",
        capacity: "32GB", type: "DDR5", brand: "Corsair", modules: "2", form: "DIMM",
        rgb: "Addressable", price: 10_900 },
      { title: "G.Skill Trident Z5 RGB DDR5 32 GB (2×16 GB) 6400 MHz",
        capacity: "32GB", type: "DDR5", brand: "G.Skill", modules: "2", form: "DIMM",
        rgb: "Addressable", price: 11_900 },
      { title: "G.Skill Trident Z5 RGB DDR5 64 GB (2×32 GB) 6000 MHz",
        capacity: "64GB", type: "DDR5", brand: "G.Skill", modules: "2", form: "DIMM",
        rgb: "Addressable", price: 22_900 },
      { title: "Kingston Fury Beast DDR5 16 GB (2×8 GB) 5600 MHz",
        capacity: "16GB", type: "DDR5", brand: "Kingston", modules: "2", form: "DIMM",
        rgb: "None", price: 5_900 },
      { title: "Crucial Pro DDR5 32 GB (2×16 GB) 5600 MHz",
        capacity: "32GB", type: "DDR5", brand: "Crucial", modules: "2", form: "DIMM",
        rgb: "None", price: 8_900 },
      { title: "Corsair Vengeance LPX DDR4 16 GB (2×8 GB) 3200 MHz",
        capacity: "16GB", type: "DDR4", brand: "Corsair", modules: "2", form: "DIMM",
        rgb: "None", price: 3_900 },
      { title: "Corsair Vengeance RGB Pro DDR4 32 GB (2×16 GB) 3600 MHz",
        capacity: "32GB", type: "DDR4", brand: "Corsair", modules: "2", form: "DIMM",
        rgb: "Addressable", price: 6_900 },
      { title: "Samsung DDR4 16 GB (1×16 GB) 3200 MHz",
        capacity: "16GB", type: "DDR4", brand: "Samsung", modules: "1", form: "DIMM",
        rgb: "None", price: 3_500 },
      { title: "Teamgroup T-Force Delta RGB DDR5 32 GB (2×16 GB) 6000 MHz",
        capacity: "32GB", type: "DDR5", brand: "Teamgroup", modules: "2", form: "DIMM",
        rgb: "Addressable", price: 9_900 },
      { title: "ADATA XPG Gammix D10 DDR4 16 GB (2×8 GB) 3200 MHz",
        capacity: "16GB", type: "DDR4", brand: "ADATA", modules: "2", form: "DIMM",
        rgb: "None", price: 3_700 },
      { title: "Lexar Ares RGB DDR5 32 GB (2×16 GB) 6000 MHz",
        capacity: "32GB", type: "DDR5", brand: "Lexar", modules: "2", form: "DIMM",
        rgb: "Addressable", price: 9_500 },
      { title: "Patriot Viper Steel DDR4 16 GB (2×8 GB) 3600 MHz",
        capacity: "16GB", type: "DDR4", brand: "Patriot", modules: "2", form: "DIMM",
        rgb: "None", price: 3_600 }
    ].freeze

    STORAGE_DEVICES = [
      { title: "Samsung 990 Pro 2 TB NVMe PCIe 4.0", capacity: "2TB",
        interface: "NVMe SSD", form: "M.2", brand: "Samsung", price: 15_900 },
      { title: "Samsung 990 Pro 1 TB NVMe PCIe 4.0", capacity: "1TB",
        interface: "NVMe SSD", form: "M.2", brand: "Samsung", price: 9_900 },
      { title: "Samsung 990 Pro 4 TB NVMe PCIe 4.0", capacity: "4TB",
        interface: "NVMe SSD", form: "M.2", brand: "Samsung", price: 31_900 },
      { title: "Samsung 980 Pro 1 TB NVMe PCIe 4.0", capacity: "1TB",
        interface: "NVMe SSD", form: "M.2", brand: "Samsung", price: 7_900 },
      { title: "Crucial P3 Plus 1 TB NVMe PCIe 4.0", capacity: "1TB",
        interface: "NVMe SSD", form: "M.2", brand: "Crucial", price: 5_900 },
      { title: "Crucial P3 Plus 2 TB NVMe PCIe 4.0", capacity: "2TB",
        interface: "NVMe SSD", form: "M.2", brand: "Crucial", price: 9_900 },
      { title: "WD Black SN850X 2 TB NVMe PCIe 4.0", capacity: "2TB",
        interface: "NVMe SSD", form: "M.2", brand: "WD", price: 14_900 },
      { title: "WD Black SN850X 1 TB NVMe PCIe 4.0", capacity: "1TB",
        interface: "NVMe SSD", form: "M.2", brand: "WD", price: 8_900 },
      { title: "Kingston KC3000 1 TB NVMe PCIe 4.0", capacity: "1TB",
        interface: "NVMe SSD", form: "M.2", brand: "Kingston", price: 7_900 },
      { title: "Seagate BarraCuda 4 TB SATA HDD", capacity: "4TB",
        interface: "SATA HDD", form: "3.5 inch", brand: "Seagate", price: 8_900 },
      { title: "WD Blue 2 TB SATA SSD", capacity: "2TB",
        interface: "SATA SSD", form: "2.5 inch", brand: "WD", price: 10_900 },
      { title: "SK hynix Platinum P41 2 TB NVMe PCIe 4.0", capacity: "2TB",
        interface: "NVMe SSD", form: "M.2", brand: "SK hynix", price: 13_900 },
      { title: "Lexar NM790 2 TB NVMe PCIe 4.0", capacity: "2TB",
        interface: "NVMe SSD", form: "M.2", brand: "Lexar", price: 10_900 }
    ].freeze

    CASES = [
      { title: "Corsair 4000D Airflow", brand: "Corsair", size: "Mid Tower",
        form: "ATX", colour: "Black", rgb: "None", price: 7_900 },
      { title: "NZXT H5 Flow", brand: "NZXT", size: "Mid Tower",
        form: "ATX", colour: "White", rgb: "None", price: 8_900 },
      { title: "Lian Li O11 Dynamic EVO", brand: "Lian Li", size: "Mid Tower",
        form: "ATX", colour: "Black", rgb: "Addressable", price: 14_900 },
      { title: "Fractal Design North", brand: "Fractal Design", size: "Mid Tower",
        form: "ATX", colour: "White", rgb: "None", price: 13_900 },
      { title: "Hyte Y60", brand: "Hyte", size: "Mid Tower",
        form: "ATX", colour: "White", rgb: "Addressable", price: 18_900 },
      { title: "be quiet! Pure Base 500DX", brand: "be quiet!", size: "Mid Tower",
        form: "ATX", colour: "Black", rgb: "Addressable", price: 9_900 },
      { title: "Cooler Master NR200P", brand: "Cooler Master", size: "Mini Tower",
        form: "Mini-ITX", colour: "White", rgb: "None", price: 8_900 },
      { title: "Montech Air 903 Max", brand: "Montech", size: "Full Tower",
        form: "E-ATX", colour: "Black", rgb: "Addressable", price: 7_900 },
      { title: "Phanteks Eclipse G360A", brand: "Phanteks", size: "Mid Tower",
        form: "ATX", colour: "Black", rgb: "Addressable", price: 8_900 },
      { title: "Antec C8", brand: "Antec", size: "Full Tower",
        form: "E-ATX", colour: "White", rgb: "None", price: 10_900 },
      { title: "Lian Li A4-H2O", brand: "Lian Li", size: "Small Form Factor",
        form: "Mini-ITX", colour: "Black", rgb: "None", price: 14_900 }
    ].freeze

    PSUS = [
      { title: "Corsair RM850x 850W 80+ Gold", brand: "Corsair", wattage: "850W",
        form: "ATX", price: 12_900 },
      { title: "Corsair SF750 750W 80+ Platinum", brand: "Corsair", wattage: "750W",
        form: "SFX", price: 14_900 },
      { title: "Seasonic Focus GX-750 750W 80+ Gold", brand: "Seasonic", wattage: "750W",
        form: "ATX", price: 10_900 },
      { title: "be quiet! Pure Power 12 M 850W 80+ Gold", brand: "be quiet!",
        wattage: "850W", form: "ATX", price: 11_900 },
      { title: "MSI MPG A1000G 1000W 80+ Gold", brand: "MSI", wattage: "1000W",
        form: "ATX", price: 15_900 },
      { title: "Cooler Master MWE 650 Bronze V2 650W", brand: "Cooler Master",
        wattage: "650W", form: "ATX", price: 5_900 },
      { title: "Thermaltake Toughpower GF3 1000W 80+ Gold", brand: "Thermaltake",
        wattage: "1000W", form: "ATX", price: 14_900 },
      { title: "EVGA SuperNOVA 750 G6 750W 80+ Gold", brand: "EVGA", wattage: "750W",
        form: "ATX", price: 11_900 },
      { title: "be quiet! Dark Power 13 1000W 80+ Titanium", brand: "be quiet!",
        wattage: "1000W", form: "ATX", price: 22_900 },
      { title: "Seasonic Prime PX-1300 1300W 80+ Platinum", brand: "Seasonic",
        wattage: ">1200W", form: "ATX", price: 29_900 }
    ].freeze

    COOLERS = [
      { title: "Noctua NH-D15 chromax.black", brand: "Noctua", type: "Air",
        socket: "AM5", price: 10_900 },
      { title: "Thermalright Peerless Assassin 120 SE", brand: "Thermalright",
        type: "Air", socket: "AM5", price: 3_900 },
      { title: "ARCTIC Liquid Freezer III 360", brand: "ARCTIC", type: "AIO",
        socket: "AM5", price: 9_900 },
      { title: "NZXT Kraken 240", brand: "NZXT", type: "AIO", socket: "LGA 1700",
        price: 13_900 },
      { title: "Corsair iCUE H150i Elite Capellix XT", brand: "Corsair", type: "AIO",
        socket: "AM5", price: 18_900 },
      { title: "be quiet! Dark Rock Pro 5", brand: "be quiet!", type: "Air",
        socket: "LGA 1700", price: 9_900 },
      { title: "Deepcool AK620 Digital", brand: "Deepcool", type: "Air",
        socket: "AM5", price: 5_900 },
      { title: "Lian Li Galahad II Trinity 360", brand: "Lian Li", type: "AIO",
        socket: "LGA 1700", price: 14_900 },
      { title: "ID-COOLING SE-214-XT", brand: "ID-COOLING", type: "Air",
        socket: "AM4", price: 2_500 },
      { title: "EK Nucleus AIO CR360 Lux", brand: "EK", type: "AIO",
        socket: "AM5", price: 16_900 }
    ].freeze

    def self.products
      @products ||= {
      "monitors" => [
        monitor("LG UltraGear 27GP850-B 27\"", "27\"", "1440p", "165Hz", "IPS", 32_900, "LG"),
        monitor("Samsung Odyssey G7 32\"", "32\"", "1440p", "240Hz", "VA", 49_900, "Samsung"),
        monitor("Dell UltraSharp U2723QE 27\"", "27\"", "4K", "60Hz", "IPS", 44_900, "Dell"),
        monitor("LG UltraGear 34GN850-B 34\" ultrapanorámico", "34\" ultrawide", "1440p",
                "144Hz", "IPS", 59_900, "LG"),
        monitor("ASUS ROG Swift PG279QM 27\"", "27\"", "1440p", "240Hz", "IPS", 64_900, "Asus"),
        monitor("AOC 24G2 24\"", "24\"", "1080p", "144Hz", "IPS", 14_900, "AOC"),
        monitor("BenQ MOBIUZ EX3210U 32\"", "32\"", "4K", "144Hz", "IPS", 69_900, "BenQ"),
        monitor("Alienware AW3423DWF 34\" OLED", "34\" ultrawide", "1440p", "165Hz",
                "OLED", 79_900, "Alienware"),
        monitor("MSI Optix G272 27\"", "27\"", "1080p", "144Hz", "IPS", 16_900, "MSI")
      ],
      "keyboards" => [
        keyboard("Keychron Q1 Pro", "75%", "Tactile", "Multi-mode", "ES", "Black",
                 "Addressable", 16_900, "Keychron"),
        keyboard("Keychron K8 Pro", "TKL", "Tactile", "Multi-mode", "ES", "Grey",
                 "Addressable", 9_900, "Keychron"),
        keyboard("Wooting 60HE", "60%", "Linear", "Wired", "US", "Black",
                 "Addressable", 17_900, "Wooting"),
        keyboard("Razer Huntsman V2", "Full", "Optical", "Wired", "ES", "Black",
                 "Addressable", 12_900, "Razer"),
        keyboard("Logitech MX Keys S", "Full", "Membrane", "Multi-mode", "ES", "Grey",
                 "None", 9_900, "Logitech"),
        keyboard("ASUS ROG Azoth", "75%", "Linear", "Multi-mode", "ES", "Black",
                 "Addressable", 22_900, "Asus"),
        keyboard("Ducky One 3", "TKL", "Linear", "Wired", "ES", "White",
                 "Addressable", 11_900, "Ducky"),
        keyboard("Corsair K70 RGB Pro", "Full", "Linear", "Wired", "ES", "Black",
                 "Addressable", 10_900, "Corsair"),
        keyboard("Akko 5075B Plus", "75%", "Tactile", "Multi-mode", "ES", "White",
                 "Addressable", 7_900, "Akko"),
        keyboard("SteelSeries Apex Pro TKL", "TKL", "Optical", "Wired", "ES", "Black",
                 "Addressable", 15_900, "SteelSeries")
      ],
      "mice" => [
        mouse("Logitech G Pro X Superlight 2", "Wireless 2.4GHz", "Black", "None",
              12_900, "Logitech"),
        mouse("Razer Viper V3 Pro", "Wireless 2.4GHz", "White", "None", 13_900, "Razer"),
        mouse("Logitech G502 X Plus", "Wireless 2.4GHz", "Black", "Addressable",
              11_900, "Logitech"),
        mouse("Razer DeathAdder V3", "Wired", "Black", "None", 6_900, "Razer"),
        mouse("SteelSeries Aerox 3 Wireless", "Wireless 2.4GHz", "Black",
              "Addressable", 7_900, "SteelSeries"),
        mouse("Glorious Model O 2", "Wired", "White", "Addressable", 5_900, "Glorious"),
        mouse("Zowie EC2-CW", "Wireless 2.4GHz", "Black", "None", 13_900, "Zowie"),
        mouse("Corsair Scimitar RGB Elite", "Wired", "Black", "Addressable", 7_900,
              "Corsair"),
        mouse("Pulsar X2V2", "Wireless 2.4GHz", "White", "None", 8_900, "Pulsar"),
        mouse("Logitech MX Master 3S", "Multi-mode", "Grey", "None", 8_900, "Logitech")
      ],
      "headphones" => [
        headset("HyperX Cloud III", "Wired", "Black", 7_900, "HyperX"),
        headset("SteelSeries Arctis Nova Pro Wireless", "Multi-mode", "Black",
                29_900, "SteelSeries"),
        headset("Logitech G Pro X 2 Lightspeed", "Wireless 2.4GHz", "White",
                19_900, "Logitech"),
        headset("Razer BlackShark V2 Pro", "Wireless 2.4GHz", "Black", 17_900, "Razer"),
        headset("Corsair Virtuoso RGB Wireless", "Multi-mode", "White", 14_900, "Corsair"),
        headset("Sony WH-1000XM5", "Bluetooth", "Black", 24_900, "Sony"),
        headset("Apple AirPods Max", "Bluetooth", "Silver", 39_900, "Apple"),
        headset("Sennheiser HD 560S", "Wired", "Black", 14_900, "Sennheiser"),
        headset("Beyerdynamic DT 990 Pro", "Wired", "Black", 12_900, "Beyerdynamic"),
        headset("Audeze Maxwell", "Wireless 2.4GHz", "Black", 29_900, "Audeze")
      ],
      "gaming-laptops" => [
        laptop("ASUS ROG Zephyrus G14 2024", "Asus", "AMD", "NVIDIA", "8GB",
               "32GB", "DDR5", "1TB", "14\"", "Black", 159_900),
        laptop("Lenovo Legion Pro 5 16", "Lenovo", "AMD", "NVIDIA", "12GB",
               "32GB", "DDR5", "1TB", "16\"", "Grey", 139_900),
        laptop("Razer Blade 16 2024", "Razer", "Intel", "NVIDIA", "16GB",
               "32GB", "DDR5", "1TB", "16\"", "Black", 249_900),
        laptop("MSI Raider GE78 HX", "MSI", "Intel", "NVIDIA", "16GB",
               "32GB", "DDR5", "2TB", "17\"", "Black", 219_900),
        laptop("Acer Predator Helios 16", "Acer", "Intel", "NVIDIA", "12GB",
               "16GB", "DDR5", "1TB", "16\"", "Black", 119_900),
        laptop("HP Omen 16", "HP", "AMD", "NVIDIA", "8GB", "16GB", "DDR5",
               "1TB", "16\"", "White", 99_900)
      ],
      "ultrabooks" => [
        laptop("Dell XPS 13 Plus", "Dell", "Intel", "Intel", "Other", "16GB",
               "LPDDR5", "512GB", "13\"", "Silver", 89_900),
        laptop("Lenovo ThinkPad X1 Carbon Gen 11", "Lenovo", "Intel", "Intel",
               "Other", "16GB", "LPDDR5", "1TB", "14\"", "Black", 99_900),
        laptop("ASUS Zenbook 14 OLED", "Asus", "Intel", "Intel", "Other", "16GB",
               "LPDDR5", "1TB", "14\"", "Grey", 79_900),
        laptop("HP Spectre x360 14", "HP", "Intel", "Intel", "Other", "16GB",
               "LPDDR5", "1TB", "14\"", "Black", 94_900),
        laptop("Acer Swift Go 14", "Acer", "Intel", "Intel", "Other", "16GB",
               "LPDDR5", "512GB", "14\"", "Silver", 59_900)
      ],
      "macbooks" => [
        laptop("MacBook Air M3 13\"", "Apple", "Apple", "Apple", "Other", "16GB",
               "LPDDR5", "512GB", "13\"", "Silver", 99_900),
        laptop("MacBook Air M2 15\"", "Apple", "Apple", "Apple", "Other", "16GB",
               "LPDDR5", "512GB", "15\"", "Grey", 94_900),
        laptop("MacBook Pro 14\" M3 Pro", "Apple", "Apple", "Apple", "Other", "Other",
               "LPDDR5", "1TB", "14\"", "Black", 169_900),
        laptop("MacBook Pro 16\" M3 Max", "Apple", "Apple", "Apple", "Other", "48GB",
               "LPDDR5", "1TB", "16\"", "Black", 269_900),
        laptop("MacBook Air M1 13\"", "Apple", "Apple", "Apple", "Other", "8GB",
               "LPDDR5", "256GB", "13\"", "Grey", 54_900)
      ],
      "other-laptops" => [
        laptop("Lenovo IdeaPad Slim 3", "Lenovo", "AMD", "Integrated", "Other",
               "8GB", "DDR4", "512GB", "15\"", "Grey", 29_900),
        laptop("HP 250 G9", "HP", "Intel", "Integrated", "Other", "8GB", "DDR4",
               "256GB", "15\"", "Black", 24_900),
        laptop("Acer Aspire 5", "Acer", "Intel", "Integrated", "Other", "16GB",
               "DDR4", "512GB", "15\"", "Silver", 34_900)
      ],
      "iphone" => [
        phone("iPhone 16 Pro 256 GB", "Apple", "256GB", "6\"-6.5\"", "Black",
              "100%", 94_900),
        phone("iPhone 15 Pro 256 GB", "Apple", "256GB", "6\"-6.5\"", "Blue",
              "90-99%", 79_900),
        phone("iPhone 15 128 GB", "Apple", "128GB", "6\"-6.5\"", "Pink",
              "90-99%", 59_900),
        phone("iPhone 14 Pro 256 GB", "Apple", "256GB", "6\"-6.5\"", "Grey",
              "80-89%", 64_900),
        phone("iPhone 13 128 GB", "Apple", "128GB", "6\"-6.5\"", "White",
              "80-89%", 39_900),
        phone("iPhone SE 3 128 GB", "Apple", "128GB", "<6\"", "Black",
              "90-99%", 27_900)
      ],
      "android-phones" => [
        phone("Samsung Galaxy S24 Ultra 512 GB", "Samsung", "512GB", ">6.5\"",
              "Grey", "100%", 89_900),
        phone("Samsung Galaxy S24 256 GB", "Samsung", "256GB", "6\"-6.5\"",
              "Black", "90-99%", 54_900),
        phone("Samsung Galaxy S23 256 GB", "Samsung", "256GB", "6\"-6.5\"",
              "White", "80-89%", 39_900),
        phone("Google Pixel 8 Pro 256 GB", "Google", "256GB", "6\"-6.5\"",
              "Blue", "90-99%", 54_900),
        phone("Xiaomi 14 512 GB", "Xiaomi", "512GB", "6\"-6.5\"", "Black",
              "90-99%", 49_900),
        phone("OnePlus 12 256 GB", "OnePlus", "256GB", ">6.5\"", "Other",
              "90-99%", 49_900),
        phone("Motorola Edge 50 Pro 256 GB", "Motorola", "256GB", "6\"-6.5\"",
              "Grey", "100%", 34_900)
      ],
      "other-phones" => [
        phone("Huawei P60 Pro 256 GB", "Other", "256GB", "6\"-6.5\"", "White",
              "80-89%", 39_900),
        phone("Nothing Phone (2) 256 GB", "Other", "256GB", "6\"-6.5\"", "White",
              "90-99%", 32_900),
        phone("Sony Xperia 1 V 256 GB", "Other", "256GB", ">6.5\"", "Black",
              "80-89%", 44_900)
      ],
      "ipad" => [
        tablet("iPad Pro 11\" M4 256 GB", "Apple", "256GB", "9\"-11\"", "Black",
               "100%", 89_900),
        tablet("iPad Air M2 11\" 128 GB", "Apple", "128GB", "9\"-11\"", "Blue",
               "90-99%", 49_900),
        tablet("iPad 10ª generación 64 GB", "Apple", "Other", "9\"-11\"", "Silver",
               "90-99%", 29_900),
        tablet("iPad mini 6 64 GB", "Apple", "Other", "<9\"", "Pink", "80-89%",
               32_900)
      ],
      "android-tablets" => [
        tablet("Samsung Galaxy Tab S9 128 GB", "Samsung", "128GB", "9\"-11\"",
               "Grey", "90-99%", 49_900),
        tablet("Samsung Galaxy Tab S9 FE 128 GB", "Samsung", "128GB", "9\"-11\"",
               "Silver", "90-99%", 29_900),
        tablet("Lenovo Tab P12 128 GB", "Lenovo", "128GB", ">11\"", "Grey",
               "80-89%", 24_900),
        tablet("Xiaomi Pad 6 256 GB", "Xiaomi", "256GB", "9\"-11\"", "Blue",
               "90-99%", 22_900)
      ],
      "other-tablets" => [
        tablet("Microsoft Surface Pro 9 256 GB", "Microsoft", "256GB", "9\"-11\"",
               "Silver", "80-89%", 59_900),
        tablet("Microsoft Surface Go 4 128 GB", "Microsoft", "128GB", "<9\"",
               "Silver", "90-99%", 34_900)
      ],
      "consoles" => [
        console("PlayStation 5 Slim 1 TB", "PlayStation 5", "1TB", 39_900, "Sony"),
        console("PlayStation 5 Pro 2 TB", "PlayStation 5", "2TB", 69_900, "Sony"),
        console("Xbox Series X 1 TB", "Xbox Series X|S", "1TB", 34_900, "Microsoft"),
        console("Xbox Series S 512 GB", "Xbox Series X|S", "512GB", 19_900, "Microsoft"),
        console("PlayStation 4 Pro 1 TB", "PlayStation 4", "1TB", 19_900, "Sony"),
        console("Xbox One X 1 TB", "Xbox One", "1TB", 16_900, "Microsoft")
      ],
      "handhelds" => [
        console("Nintendo Switch OLED", "Nintendo Switch", "Other", 24_900, "Nintendo"),
        console("Nintendo Switch 2", "Nintendo Switch 2", "256GB", 42_900, "Nintendo"),
        console("Steam Deck OLED 512 GB", "Steam Deck", "512GB", 44_900, "Valve"),
        console("ROG Ally X", "ROG Ally", "1TB", 59_900, "Asus"),
        console("Lenovo Legion Go", "PC", "512GB", 49_900, "Lenovo")
      ],
      "retro-consoles" => [
        console("PlayStation 2 Slim", "Retro", "Other", 8_900, "Sony"),
        console("Nintendo GameCube", "Retro", "Other", 9_900, "Nintendo"),
        console("Super Nintendo SNES", "Retro", "Other", 12_900, "Nintendo"),
        console("Nintendo 64", "Retro", "Other", 11_900, "Nintendo"),
        console("Sega Mega Drive", "Retro", "Other", 7_900, "Sega"),
        console("Sega Dreamcast", "Retro", "Other", 13_900, "Sega")
      ],
      "retro-handhelds" => [
        console("Game Boy Advance SP", "Retro", "Other", 9_900, "Nintendo"),
        console("Nintendo DS Lite", "Retro", "Other", 5_900, "Nintendo"),
        console("PSP 3000", "Retro", "Other", 8_900, "Sony"),
        console("Nintendo 3DS XL", "Retro", "Other", 12_900, "Nintendo"),
        console("Game Boy Color", "Retro", "Other", 7_900, "Nintendo")
      ],
      "vr-headsets" => [
        console("Meta Quest 3 128 GB", "Other", "128GB", 32_900, "Meta"),
        console("Meta Quest 2 128 GB", "Other", "128GB", 17_900, "Meta"),
        console("Valve Index Full Kit", "PC", "Other", 59_900, "Valve"),
        console("PlayStation VR2", "PlayStation 5", "Other", 34_900, "Sony"),
        console("Pico 4 128 GB", "Other", "128GB", 21_900, "Pico")
      ],
      "cpus" => CPUS,
      "gpus" => GPUS,
      "cpu-coolers" => COOLERS,
      "power-supplies" => PSUS,
      "cases" => CASES,
      "memory" => RAMS,
      "storage" => STORAGE_DEVICES,
      "motherboards" => [
        motherboard("ASUS ROG Strix B650E-F Gaming WiFi", "Asus", "AM5", "DDR5",
                    "ATX", "Ethernet and Wi-Fi", 21_900),
        motherboard("MSI MAG B760 Tomahawk WiFi", "MSI", "LGA 1700", "DDR5", "ATX",
                    "Ethernet and Wi-Fi", 16_900),
        motherboard("Gigabyte X670E Aorus Master", "Gigabyte", "AM5", "DDR5",
                    "E-ATX", "Ethernet and Wi-Fi", 34_900),
        motherboard("ASRock B550M Pro4", "ASRock", "AM4", "DDR4", "Micro-ATX",
                    "Ethernet only", 7_900),
        motherboard("NZXT N7 B650E", "NZXT", "AM5", "DDR5", "ATX",
                    "Ethernet and Wi-Fi", 24_900),
        motherboard("ASUS Prime Z790-A WiFi", "Asus", "LGA 1700", "DDR5", "ATX",
                    "Ethernet and Wi-Fi", 19_900)
      ],
      "motherboard-bundles" => [
        bundle("AMD Ryzen 7 7800X3D + MSI B650 + 32 GB DDR5", "AMD", "AM5",
               "MSI", "ATX", 49_900),
        bundle("Intel Core i5-14600K + ASUS Z790 + 32 GB DDR5", "Intel", "LGA 1700",
               "Asus", "ATX", 46_900),
        bundle("AMD Ryzen 5 7600X + ASRock B650M + 16 GB DDR5", "AMD", "AM5",
               "ASRock", "Micro-ATX", 32_900),
        bundle("Intel Core i7-13700K + Gigabyte Z790 + 32 GB DDR4", "Intel",
               "LGA 1700", "Gigabyte", "ATX", 44_900)
      ],
      "case-fans" => [
        fan("ARCTIC P12 PWM PST (pack de 5)", "Addressable", 3_900, "ARCTIC"),
        fan("Noctua NF-A12x25 PWM", "None", 2_900, "Noctua"),
        fan("Lian Li UNI Fan SL Infinity 120 (pack de 3)", "Addressable", 7_900,
            "Lian Li"),
        fan("Corsair QL120 RGB (pack de 3)", "Addressable", 6_900, "Corsair"),
        fan("be quiet! Silent Wings 4 140 mm", "None", 2_500, "be quiet!")
      ],
      "controllers" => [
        controller("Sony DualSense PS5", "PlayStation 5", "Multi-mode", "White",
                   5_900, "Sony"),
        controller("Sony DualSense Edge", "PlayStation 5", "Multi-mode", "White",
                   16_900, "Sony"),
        controller("Xbox Wireless Controller", "Xbox Series X|S", "Bluetooth",
                   "Black", 4_500, "Microsoft"),
        controller("Nintendo Switch Pro Controller", "Nintendo Switch", "Bluetooth",
                   "Black", 4_900, "Nintendo"),
        controller("8BitDo Ultimate Bluetooth", "PC", "Multi-mode", "White",
                   5_900, "8BitDo"),
        controller("GameSir G7 SE", "Xbox Series X|S", "Wired", "White", 3_900,
                   "GameSir")
      ],
      "retro-controllers" => [
        controller("Mando Nintendo 64 original", "Retro", "Wired", "Grey", 2_900,
                   "Nintendo"),
        controller("Mando SNES Classic", "Retro", "Wired", "Grey", 2_500, "Nintendo"),
        controller("Arcade Stick Hori Real Arcade Pro", "PC", "Wired", "Black",
                   8_900, "Hori"),
        controller("DualShock 2 PS2", "Retro", "Wired", "Black", 1_900, "Sony")
      ],
      "sim-racing" => [
        simple("Logitech G29 + pedales", "Logitech", 16_900),
        simple("Logitech G923 Trueforce", "Logitech", 24_900),
        simple("Fanatec CSL DD 5 Nm + pedalera", "Fanatec", 39_900),
        simple("Thrustmaster T300RS GT", "Thrustmaster", 27_900),
        simple("Moza R5 Direct Drive Bundle", "Moza", 44_900)
      ],
      "webcams" => [
        simple("Logitech Brio 4K", "Logitech", 12_900),
        simple("Logitech C920 HD Pro", "Logitech", 5_900),
        simple("Elgato Facecam MK.2", "Elgato", 12_900),
        simple("Razer Kiyo Pro Ultra", "Razer", 24_900)
      ],
      "microphones" => [
        simple("Shure MV7 USB/XLR", "Shure", 21_900),
        simple("Blue Yeti X", "Blue", 9_900),
        simple("Elgato Wave:3", "Elgato", 11_900),
        simple("Rode NT-USB+", "Rode", 14_900)
      ],
      "speakers" => [
        simple("Logitech Z407 2.1 Bluetooth", "Logitech", 6_900),
        simple("Edifier R1280T", "Edifier", 8_900),
        simple("Audioengine A2+", "Audioengine", 19_900),
        simple("Creative Pebble Pro", "Creative", 4_900)
      ],
      "external-storage" => [
        external("Samsung T7 1 TB USB-C", "1TB", "Samsung", 7_900),
        external("Samsung T7 Shield 2 TB", "2TB", "Samsung", 12_900),
        external("WD My Passport 2 TB", "2TB", "WD", 6_900),
        external("SanDisk Extreme Portable 1 TB", "1TB", "Other", 8_900),
        external("Crucial X9 Pro 2 TB", "2TB", "Crucial", 13_900)
      ],
      "other-peripherals" => [
        simple("Capturadora Elgato HD60 X", "Elgato", 12_900),
        simple("Hub USB-C Anker 7 en 1", "Anker", 3_900),
        simple("Soporte de auriculares bajo escritorio", "Other", 1_500)
      ],
      "expansion-cards" => [
        simple("Elgato 4K60 Pro MK.2 capturadora", "Elgato", 17_900),
        simple("ASUS Xonar AE tarjeta de sonido", "Asus", 4_900),
        simple("TP-Link Archer TX3000E WiFi 6", "TP-Link", 3_900)
      ],
      "network-adapters" => [
        simple("Adaptador USB WiFi 6 TP-Link Archer TX20U", "TP-Link", 2_900),
        simple("Intel AX210 PCIe WiFi 6E", "Intel", 2_500),
        simple("Adaptador Ethernet USB-C 2.5G", "Other", 2_900)
      ],
      "other-components" => [
        simple("Kit de cables personalizados Corsair", "Corsair", 4_900),
        simple("Hub ARGB NZXT", "NZXT", 1_900),
        simple("Pasta térmica Thermal Grizzly Kryonaut", "Thermal Grizzly", 900),
        simple("Riser PCIe 4.0 Lian Li", "Lian Li", 3_900)
      ],
      "desk-accessories" => [
        simple("Brazo de monitor Ergotron LX", "Ergotron", 8_900),
        simple("Alfombrilla XL PCMarket", "PCMarket", 1_900),
        simple("Organizador de cables bajo escritorio", "Other", 1_500),
        simple("Soporte portátil de aluminio", "Other", 2_500)
      ],
      "art-decor" => [
        simple("Lámina Cyberpunk 2077 enmarcada", "Other", 3_900),
        simple("Letrero LED neón \"Game On\"", "Other", 4_900),
        simple("Póster pixel art 40×60", "Other", 2_500)
      ],
      "collectibles" => [
        simple("Figura Fallout T-51b", "Other", 7_900),
        simple("Estatua Pokémon Charizard", "Other", 9_900),
        simple("Casco Master Chief réplica", "Other", 12_900)
      ],
      "clothing-gear" => [
        simple("Sudadera PCMarket edición limitada", "PCMarket", 3_900),
        simple("Gorra RGB Team", "Other", 1_900),
        simple("Calcetines gaming pack 3", "Other", 1_500)
      ],
      "other-accessories" => [
        simple("Skin para Steam Deck", "Other", 1_900),
        simple("Pack de keycaps PBT", "Other", 3_900),
        simple("Stickers para portátil", "Other", 900)
      ],
      "games" => [
        game("Cyberpunk 2077 Ultimate Edition", "PlayStation 5", 3_900),
        game("Elden Ring Shadow of the Erdtree", "PlayStation 5", 4_900),
        game("Baldur's Gate 3", "PC", 4_500),
        game("EA Sports FC 25", "PlayStation 5", 3_500),
        game("Call of Duty: Modern Warfare III", "Xbox Series X|S", 3_900),
        game("Zelda: Tears of the Kingdom", "Nintendo Switch", 4_500),
        game("Mario Kart 8 Deluxe", "Nintendo Switch", 3_900),
        game("GTA V Enhanced", "PC", 2_900)
      ],
      "software" => [
        simple("Windows 11 Pro licencia OEM", "Microsoft", 2_900),
        simple("Microsoft 365 Family 1 año", "Microsoft", 5_900),
        simple("Adobe Creative Cloud 1 año", "Adobe", 29_900),
        simple("Norton 360 Deluxe 1 año", "Norton", 2_900)
      ]
      }.freeze
    end

    class << self
      def locations
        LOCATIONS
      end

      def condition_multiplier(condition)
        CONDITION_MULTIPLIERS.fetch(condition.to_s, 1.0)
      end

      def product_for(category_slug, rng)
        case category_slug
        when "gaming-pcs", "creator-rigs", "streaming-rigs", "local-ai-rigs"
          pc(category_slug, rng)
        when "gpus" then gpu_product(rng)
        when "cpus" then cpu_product(rng)
        when "cpu-coolers" then cooler_product(rng)
        when "memory" then ram_product(rng)
        when "storage" then storage_product(rng)
        when "cases" then case_product(rng)
        when "power-supplies" then psu_product(rng)
        else
          category_products = products[category_slug]
          return nil if category_products.blank?

          category_products.sample(random: rng).dup
        end
      end

      def pc(category_slug, rng)
        gpu = GPU_BUCKETS.fetch(category_slug, GPUS).sample(random: rng)
        cpu = CPUS.sample(random: rng)
        ram = RAMS.sample(random: rng)
        storage = STORAGE_DEVICES.sample(random: rng)
        pc_case = CASES.sample(random: rng)
        psu = PSUS.sample(random: rng)
        cooler = COOLERS.sample(random: rng)
        colour = pc_case[:colour]
        tier = gpu[:tier]

        {
          title: "#{cpu[:name]} | #{gpu[:model]} | #{ram[:capacity]} #{ram[:type]} | " \
                 "#{storage[:capacity]} #{storage[:interface].split.first}",
          brand: gpu[:brand],
          price_cents: pc_price(gpu, cpu, ram, storage, pc_case, psu, cooler),
          tier: tier,
          specs: {
            "cpu_brand" => cpu[:brand],
            "cpu_core_count" => cpu[:cores],
            "cpu_cooler_brand" => cooler[:brand],
            "cpu_cooler_type" => cooler[:type],
            "gpu_chipset" => gpu[:chipset],
            "gpu_model" => gpu[:model],
            "gpu_memory" => gpu[:memory],
            "memory_capacity" => ram[:capacity],
            "memory_type" => ram[:type],
            "storage_capacity" => storage[:capacity],
            "storage_interface" => storage[:interface],
            "networking" => "Ethernet and Wi-Fi",
            "case_brand" => pc_case[:brand],
            "case_size" => pc_case[:size],
            "colour" => colour,
            "psu_brand" => psu[:brand],
            "psu_wattage" => psu[:wattage],
            "rgb_lighting" => pc_case[:rgb]
          },
          gpu_model: gpu[:model]
        }
      end

      def gpu_product(rng)
        gpu = GPUS.sample(random: rng)
        {
          title: gpu[:label], brand: gpu[:brand], price_cents: gpu[:price], tier: gpu[:tier],
          specs: { "gpu_chipset" => gpu[:chipset], "gpu_model" => gpu[:model],
                   "gpu_memory" => gpu[:memory] },
          gpu_model: gpu[:model]
        }
      end

      def cpu_product(rng)
        cpu = CPUS.sample(random: rng)
        {
          title: "#{cpu[:brand]} #{cpu[:name]}", brand: cpu[:brand],
          price_cents: cpu[:price],
          specs: { "cpu_brand" => cpu[:brand], "cpu_core_count" => cpu[:cores],
                   "cpu_socket" => cpu[:socket] }
        }
      end

      def cooler_product(rng)
        cooler = COOLERS.sample(random: rng)
        {
          title: cooler[:title], brand: cooler[:brand], price_cents: cooler[:price],
          specs: { "cpu_cooler_brand" => cooler[:brand], "cpu_cooler_type" => cooler[:type],
                   "cpu_socket" => cooler[:socket] }
        }
      end

      def ram_product(rng)
        ram = RAMS.sample(random: rng)
        {
          title: ram[:title], brand: ram[:brand], price_cents: ram[:price],
          specs: { "memory_capacity" => ram[:capacity], "memory_type" => ram[:type],
                   "memory_brand" => ram[:brand], "memory_modules" => ram[:modules],
                   "memory_form_factor" => ram[:form], "rgb_lighting" => ram[:rgb] }
        }
      end

      def storage_product(rng)
        disk = STORAGE_DEVICES.sample(random: rng)
        {
          title: disk[:title], brand: disk[:brand], price_cents: disk[:price],
          specs: { "storage_capacity" => disk[:capacity],
                   "storage_interface" => disk[:interface],
                   "storage_form_factor" => disk[:form], "storage_brand" => disk[:brand] }
        }
      end

      def case_product(rng)
        pc_case = CASES.sample(random: rng)
        {
          title: pc_case[:title], brand: pc_case[:brand], price_cents: pc_case[:price],
          specs: { "case_brand" => pc_case[:brand], "case_size" => pc_case[:size],
                   "form_factor" => pc_case[:form], "colour" => pc_case[:colour],
                   "rgb_lighting" => pc_case[:rgb] }
        }
      end

      def psu_product(rng)
        psu = PSUS.sample(random: rng)
        {
          title: psu[:title], brand: psu[:brand], price_cents: psu[:price],
          specs: { "psu_brand" => psu[:brand], "psu_wattage" => psu[:wattage],
                   "psu_form_factor" => psu[:form] }
        }
      end

      def valid_cif(seed)
        digits = format("%07d", (seed.to_i % 9_999_999) + 1)
        sum = digits.chars.each_with_index.sum do |digit, index|
          number = digit.to_i
          if index.even?
            doubled = number * 2
            doubled > 9 ? doubled - 9 : doubled
          else
            number
          end
        end
        control = (10 - (sum % 10)) % 10
        "B#{digits}#{control}"
      end

      private

      GPU_BUCKETS = {
        "gaming-pcs" => GPUS,
        "creator-rigs" => GPUS.select { |gpu| gpu[:tier] >= 70 },
        "streaming-rigs" => GPUS.select { |gpu| gpu[:tier] >= 55 },
        "local-ai-rigs" => GPUS.select { |gpu| gpu[:memory].to_i >= 12 }
      }.freeze

      def pc_price(gpu, cpu, ram, storage, pc_case, psu, cooler)
        components = gpu[:price] + cpu[:price] + ram[:price] + storage[:price] +
                     pc_case[:price] + psu[:price] + cooler[:price]
        [ (components * 0.92).round + 6_900, 39_900 ].max
      end

      def monitor(title, size, resolution, refresh, panel, price, brand)
        { title: title, brand: brand, price_cents: price,
          specs: { "monitor_size" => size, "monitor_resolution" => resolution,
                   "refresh_rate" => refresh, "panel_type" => panel } }
      end

      def keyboard(title, size, switch, connection, layout, colour, rgb, price, brand)
        { title: title, brand: brand, price_cents: price,
          specs: { "keyboard_size" => size, "switch_type" => switch,
                   "connection" => connection, "keyboard_layout" => layout,
                   "colour" => colour, "rgb_lighting" => rgb } }
      end

      def mouse(title, connection, colour, rgb, price, brand)
        { title: title, brand: brand, price_cents: price,
          specs: { "connection" => connection, "colour" => colour,
                   "rgb_lighting" => rgb } }
      end

      def headset(title, connection, colour, price, brand)
        { title: title, brand: brand, price_cents: price,
          specs: { "connection" => connection, "colour" => colour } }
      end

      def laptop(title, brand, cpu_brand, gpu_chipset, gpu_memory, memory, memory_type,
                 storage, screen, colour, price)
        { title: title, brand: brand, price_cents: price,
          specs: { "laptop_brand" => brand, "cpu_brand" => cpu_brand,
                   "gpu_chipset" => gpu_chipset, "gpu_memory" => gpu_memory,
                   "memory_capacity" => memory, "memory_type" => memory_type,
                   "storage_capacity" => storage, "screen_size" => screen,
                   "battery_health" => "90-99%", "colour" => colour } }
      end

      def phone(title, brand, storage, screen, colour, battery, price)
        { title: title, brand: brand, price_cents: price,
          specs: { "phone_brand" => brand, "storage_capacity" => storage,
                   "phone_screen_size" => screen, "colour" => colour,
                   "battery_health" => battery } }
      end

      def tablet(title, brand, storage, screen, colour, battery, price)
        { title: title, brand: brand, price_cents: price,
          specs: { "tablet_brand" => brand, "storage_capacity" => storage,
                   "tablet_screen_size" => screen, "colour" => colour,
                   "battery_health" => battery } }
      end

      def console(title, platform, storage, price, brand)
        { title: title, brand: brand, price_cents: price,
          specs: { "platform" => platform, "storage_capacity" => storage } }
      end

      def motherboard(title, brand, socket, memory_type, form_factor, networking, price)
        { title: title, brand: brand, price_cents: price,
          specs: { "motherboard_brand" => brand, "cpu_socket" => socket,
                   "memory_type" => memory_type, "form_factor" => form_factor,
                   "networking" => networking } }
      end

      def bundle(title, cpu_brand, socket, motherboard_brand, form_factor, price)
        { title: title, brand: motherboard_brand, price_cents: price,
          specs: { "cpu_brand" => cpu_brand, "cpu_socket" => socket,
                   "motherboard_brand" => motherboard_brand,
                   "form_factor" => form_factor } }
      end

      def fan(title, rgb, price, brand)
        { title: title, brand: brand, price_cents: price,
          specs: { "rgb_lighting" => rgb } }
      end

      def controller(title, platform, connection, colour, price, brand)
        { title: title, brand: brand, price_cents: price,
          specs: { "platform" => platform, "connection" => connection,
                   "colour" => colour } }
      end

      def external(title, capacity, brand, price)
        { title: title, brand: brand, price_cents: price,
          specs: { "storage_capacity" => capacity, "storage_brand" => brand } }
      end

      def game(title, platform, price)
        { title: title, brand: "Other", price_cents: price,
          specs: { "platform" => platform } }
      end

      def simple(title, brand, price)
        { title: title, brand: brand, price_cents: price, specs: {} }
      end
    end
  end
end
