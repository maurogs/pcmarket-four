# Which filters each category offers (children inherit the parent's filters
# at runtime — see Category#effective_filter_definitions — so only a few
# broad keys are attached to the branch roots).

def seed_category_filter(category_slug, definition_key)
  category = Category.find_by!(slug: category_slug)
  definition = FilterDefinition.find_by!(key: definition_key)
  CategoryFilter.find_or_create_by!(category: category, filter_definition: definition)
end

CATEGORY_FILTERS = {
  # Branch roots (broad keys children inherit).
  "components" => %w[cpu_brand gpu_chipset gpu_model memory_capacity memory_type storage_capacity storage_brand case_brand psu_brand motherboard_brand rgb_lighting],
  "peripherals" => %w[peripheral_brand monitor_size monitor_resolution monitor_refresh_rate connectivity rgb_lighting],
  # Component leaves.
  "gpus" => %w[gpu_chipset gpu_model gpu_memory],
  "cpus" => %w[cpu_brand cpu_core_count cpu_socket],
  "cpu-coolers" => %w[cpu_cooler_brand cpu_cooler_type],
  "motherboards" => %w[motherboard_brand motherboard_form_factor cpu_socket motherboard_networking],
  "motherboard-bundles" => %w[motherboard_brand cpu_brand cpu_socket motherboard_form_factor],
  "memory" => %w[memory_capacity memory_brand memory_type memory_form_factor],
  "storage" => %w[storage_capacity storage_interface storage_form_factor storage_brand],
  "cases" => %w[case_brand case_form_factor case_color rgb_lighting],
  "case-fans" => %w[peripheral_brand rgb_lighting],
  "power-supplies" => %w[psu_brand psu_wattage psu_form_factor],
  "expansion-cards" => %w[peripheral_brand],
  "network-adapters" => %w[peripheral_brand connectivity],
  "other-components" => %w[peripheral_brand],
  # Peripheral leaves.
  "monitors" => %w[monitor_size monitor_resolution monitor_refresh_rate connectivity],
  "headphones" => %w[peripheral_brand connectivity rgb_lighting],
  "keyboards" => %w[peripheral_brand connectivity rgb_lighting],
  "mice" => %w[peripheral_brand connectivity rgb_lighting],
  "speakers" => %w[peripheral_brand connectivity],
  "controllers" => %w[peripheral_brand console_platform connectivity],
  "retro-controllers" => %w[peripheral_brand console_platform],
  "sim-racing" => %w[peripheral_brand connectivity],
  "webcams" => %w[peripheral_brand connectivity],
  "vr" => %w[peripheral_brand connectivity],
  "external-storage" => %w[storage_brand storage_capacity storage_interface connectivity],
  "other-peripherals" => %w[peripheral_brand connectivity],
  # Full systems and devices.
  "gaming-pcs" => %w[cpu_brand cpu_core_count gpu_chipset gpu_model gpu_memory memory_capacity memory_type storage_capacity storage_interface case_form_factor psu_wattage rgb_lighting],
  "workstations" => %w[cpu_brand cpu_core_count gpu_chipset gpu_memory memory_capacity memory_type storage_capacity motherboard_form_factor psu_wattage],
  "laptops" => %w[cpu_brand cpu_core_count gpu_chipset gpu_model gpu_memory memory_capacity memory_type storage_capacity laptop_screen_size connectivity rgb_lighting],
  "phones" => %w[phone_brand phone_storage connectivity],
  "tablets" => %w[phone_brand phone_storage connectivity],
  "consoles" => %w[console_platform],
  "gaming-handhelds" => %w[console_platform],
  "retro-consoles" => %w[console_platform],
  "retro-handhelds" => %w[console_platform],
  # Games.
  "games" => %w[console_platform]
}.freeze

CATEGORY_FILTERS.each do |category_slug, keys|
  keys.each { |key| seed_category_filter(category_slug, key) }
end
