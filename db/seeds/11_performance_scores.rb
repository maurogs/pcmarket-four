# PC Finder step 2: relative performance tiers (0–100) on the GPU options,
# plus the `cpu_model` filter definition the scorer blends with `gpu_model`.
# Scores are only written when missing (admin edits survive re-seeds);
# options absent from the maps stay nil. Helpers live in earlier seed files.

# Relative GPU tiers keyed by option value slug. Entries for models that are
# not seeded yet (RTX 50 series, GTX era, …) simply never match an option.
# rubocop:disable Layout/LineLength
GPU_SCORES = {
  "rtx-5090" => 100, "rtx-4090" => 95, "rtx-5080" => 88, "rtx-4080" => 82,
  "rtx-5070-ti" => 78, "rtx-4070-ti" => 72, "rtx-5070" => 70, "rtx-3090" => 68,
  "rtx-4070" => 64, "rtx-3080" => 62, "rtx-5060-ti" => 58, "rtx-3070" => 55,
  "rtx-4060-ti" => 52, "rtx-5060" => 50, "rtx-2080-ti" => 50, "rtx-3060-ti" => 46,
  "rtx-4060" => 45, "rtx-3060" => 38, "rtx-2070" => 38, "rtx-2060" => 30,
  "rtx-3050" => 28,
  "rx-9070-xt" => 80, "rx-9070" => 74, "rx-7900-xtx" => 84, "rx-7900-xt" => 76,
  "rx-7800-xt" => 66, "rx-6950-xt" => 66, "rx-7700-xt" => 58, "rx-6800-xt" => 60,
  "rx-7600" => 40, "rx-6700-xt" => 48, "rx-6650-xt" => 36, "rx-6600" => 32,
  "arc-b580" => 44, "arc-a770" => 40, "arc-a750" => 36,
  "gtx-1660-super" => 24, "gtx-1660" => 22, "gtx-1060" => 20, "gtx-1650" => 18, "gtx-1050-ti" => 15
}.freeze

# Common CPUs with the same relative tiers (gaming-leaning X3D parts score
# above raw multi-core monsters on this scale).
CPU_OPTIONS = [
  [ "Ryzen 7 9800X3D", 95 ], [ "Ryzen 9 9950X", 92 ], [ "Ryzen 7 7800X3D", 90 ],
  [ "Core Ultra 9 285K", 88 ], [ "Ryzen 9 7950X", 86 ], [ "Core i9-14900K", 85 ],
  [ "Core i9-13900K", 82 ], [ "Core Ultra 7 265K", 80 ], [ "Core i7-14700K", 80 ],
  [ "Ryzen 5 9600X", 78 ], [ "Core i9-12900K", 76 ], [ "Core Ultra 5 245K", 76 ],
  [ "Core i7-13700K", 75 ], [ "Ryzen 7 5800X3D", 74 ], [ "Ryzen 5 7600X", 72 ], [ "Core i5-14600K", 72 ],
  [ "Ryzen 7 5700X3D", 68 ], [ "Core i7-12700K", 68 ], [ "Core i5-13600K", 68 ],
  [ "Ryzen 9 5900X", 66 ], [ "Ryzen 7 5800X", 60 ], [ "Core i5-13400F", 58 ],
  [ "Ryzen 5 5600X", 55 ], [ "Ryzen 5 5600", 52 ], [ "Core i5-12400F", 52 ],
  [ "Ryzen 5 3600", 40 ], [ "Core i5-10400F", 38 ], [ "Ryzen 7 2700X", 32 ],
  [ "Core i7-6700", 22 ]
].freeze
# rubocop:enable Layout/LineLength

gpu_definition = FilterDefinition.find_by!(key: "gpu_model")
GPU_SCORES.each do |value, score|
  option = FilterOption.find_by(filter_definition: gpu_definition, value: value)
  next if option.nil? || option.performance_score.present?

  option.update!(performance_score: score)
end

# CPU model filter: used for the PC Finder score blend, so it renders in the
# sell form but stays out of the sidebar (the brand/core-count facets cover it).
seed_record(FilterDefinition, {
  key: "cpu_model",
  group_translations: filter_group("cpu"),
  label_translations: t6("CPU model", "Modelo de CPU", "Modèle du CPU", "CPU-Modell", "Modello CPU", "Modelo de CPU"),
  input_type: "multi_select",
  position: 36,
  show_in_sidebar: false,
  show_in_listing_form: true,
  active: true
}, %i[key])

cpu_definition = FilterDefinition.find_by!(key: "cpu_model")
CPU_OPTIONS.each_with_index do |(display, score), index|
  seed_record(FilterOption, {
    filter_definition_id: cpu_definition.id,
    value: display.parameterize(separator: "-"),
    label_translations: same_translations(display),
    performance_score: score,
    position: index + 1,
    active: true
  }, %i[filter_definition_id value])
end

# Full systems and CPU listings get the filter (children inherit it).
%w[gaming-pcs workstations cpus].each { |slug| seed_category_filter(slug, "cpu_model") }
