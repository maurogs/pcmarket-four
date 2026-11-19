# Product labels (marketing badges sellers attach to listings, e.g.
# "Value GPUs") and seller tags (aesthetic/style tags for builds, e.g. "rgb"
# or "noctua" — NOT seller trust badges; seller verification is the
# Store#verified boolean). Both are admin-editable, translatable rows
# keyed by slug.

# Previous run slugs that do not exist anymore — removed so re-seeding
# converges on the current set.
ProductLabel.destroy_by(slug: %w[value mid_range pro_gamer])
SellerTag.destroy_by(slug: %w[verified top_rated quick_shipping business])

product_labels = [
  [ "value_pcs", "#16a34a", t6("Value PCs", "PCs calidad-precio", "PCs bon rapport qualité-prix", "PCs Preis-Leistung", "PC qualità-prezzo", "PCs qualidade-preço") ],
  [ "mid_range_pcs", "#2563eb", t6("Mid-Range PCs", "PCs de gama media", "PCs de milieu de gamme", "PCs der Mittelklasse", "PC di fascia media", "PCs de gama média") ],
  [ "pro_gamer_pcs", "#9333ea", t6("Pro Gamer PCs", "PCs Pro Gamer", "PCs Pro Gamer", "Pro-Gamer-PCs", "PC Pro Gamer", "PCs Pro Gamer") ],
  [ "featured", "#f59e0b", t6("Featured", "Destacado", "À la une", "Empfohlen", "In evidenza", "Em destaque") ],
  [ "rare", "#ec4899", t6("Rare", "Raro", "Rare", "Selten", "Raro", "Raro") ],
  [ "value_gpus", "#16a34a", t6("Value GPUs", "GPU calidad-precio", "GPU bon rapport qualité-prix", "GPUs Preis-Leistung", "GPU qualità-prezzo", "GPUs qualidade-preço") ],
  [ "mid_range_gpus", "#2563eb", t6("Mid-Range GPUs", "GPU de gama media", "GPU de milieu de gamme", "GPUs der Mittelklasse", "GPU di fascia media", "GPUs de gama média") ],
  [ "pro_gamer_gpus", "#9333ea", t6("Pro Gamer GPUs", "GPU Pro Gamer", "GPU Pro Gamer", "Pro-Gamer-GPUs", "GPU Pro Gamer", "GPUs Pro Gamer") ],
  [ "value_cpus", "#16a34a", t6("Value CPUs", "CPU calidad-precio", "CPU bon rapport qualité-prix", "CPUs Preis-Leistung", "CPU qualità-prezzo", "CPUs qualidade-preço") ],
  [ "mid_range_cpus", "#2563eb", t6("Mid-Range CPUs", "CPU de gama media", "CPU de milieu de gamme", "CPUs der Mittelklasse", "CPU di fascia media", "CPUs de gama média") ],
  [ "pro_gamer_cpus", "#9333ea", t6("Pro Gamer CPUs", "CPU Pro Gamer", "CPU Pro Gamer", "Pro-Gamer-CPUs", "CPU Pro Gamer", "CPUs Pro Gamer") ],
  [ "free_shipping", "#0d9488", t6("Free Shipping", "Envío gratis", "Livraison gratuite", "Kostenloser Versand", "Spedizione gratuita", "Envio grátis") ],
  [ "deal", "#dc2626", t6("Deal", "Chollo", "Bonne affaire", "Schnäppchen", "Affare", "Oferta") ]
].freeze

product_labels.each_with_index do |(slug, color, names), index|
  seed_record(ProductLabel, { slug: slug, color: color, name_translations: names, position: index + 1, active: true }, %i[slug])
end

seller_tags = [
  [ "anime", same_translations("Anime") ],
  [ "minimalist", t6("Minimalist", "Minimalista", "Minimaliste", "Minimalistisch", "Minimalista", "Minimalista") ],
  [ "rgb", same_translations("RGB") ],
  [ "blackout", same_translations("Blackout") ],
  [ "whiteout", same_translations("Whiteout") ],
  [ "compact", t6("Compact", "Compacto", "Compact", "Kompakt", "Compatto", "Compacto") ],
  [ "cozy", t6("Cozy", "Acogedor", "Cosy", "Gemütlich", "Accogliente", "Acolhedor") ],
  [ "glass", t6("Glass", "Cristal", "Verre", "Glas", "Vetro", "Vidro") ],
  [ "lo_fi", same_translations("Lo-Fi") ],
  [ "luxe", t6("Luxe", "Lujo", "Luxe", "Luxus", "Lusso", "Luxo") ],
  [ "max_performance", t6("Max Performance", "Máximo rendimiento", "Performance maximale", "Maximale Leistung", "Prestazioni massime", "Desempenho máximo") ],
  [ "noctua", same_translations("Noctua") ],
  [ "rainbow", t6("Rainbow", "Arcoíris", "Arc-en-ciel", "Regenbogen", "Arcobaleno", "Arco-íris") ],
  [ "retro", same_translations("Retro") ],
  [ "sakura", same_translations("Sakura") ],
  [ "sci_fi", t6("Sci-Fi", "Ciencia ficción", "Science-fiction", "Sci-Fi", "Fantascienza", "Ficção científica") ],
  [ "space", t6("Space", "Espacial", "Espace", "Weltraum", "Spazio", "Espacial") ],
  [ "steampunk", same_translations("Steampunk") ],
  [ "superhero", t6("Superhero", "Superhéroe", "Super-héros", "Superheld", "Supereroe", "Super-herói") ],
  [ "wood", t6("Wood", "Madera", "Bois", "Holz", "Legno", "Madeira") ]
].freeze

seller_tags.each_with_index do |(slug, names), index|
  seed_record(SellerTag, { slug: slug, name_translations: names, position: index + 1, active: true }, %i[slug])
end
