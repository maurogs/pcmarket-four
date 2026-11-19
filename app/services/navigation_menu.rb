# Builds the data-driven header navigation (desktop mega menu + mobile
# drawer) from the Category tree plus curated merchandising links (budget
# labels, GPU chipsets, theme tags). Missing categories/labels are skipped
# silently so the menu degrades gracefully on a partial catalog.
#
# Results are plain structs (Marshal-safe) cached per locale on
# Category/label/data timestamps; the header additionally fragment-caches
# the rendered HTML on the same inputs.
class NavigationMenu
  Link = Struct.new(:label, :href, keyword_init: true)
  Column = Struct.new(:title, :links, keyword_init: true)
  Promo = Struct.new(:key, :title, :body, :href, keyword_init: true)
  Item = Struct.new(:key, :label, :href, :columns, :promos, keyword_init: true)

  CACHE_TTL = 1.hour

  # Curated ProductLabel slugs used for the budget links, per top item.
  BUDGET_LABELS = {
    "gaming_pcs" => %w[value_pcs mid_range_pcs pro_gamer_pcs],
    "gpus" => %w[value_gpus mid_range_gpus pro_gamer_gpus]
  }.freeze
  THEME_TAGS = %w[anime minimalist rgb].freeze

  include Rails.application.routes.url_helpers

  def self.items(locale: I18n.locale)
    new(locale).items
  end

  # Shared by the header views for their fragment-cache key.
  def self.cache_stamp
    [
      "navigation_menu/v1/#{I18n.locale}",
      Category.maximum(:updated_at).to_f.round(2),
      AppSettings.enabled?(:sell_to_us_enabled)
    ].join("/")
  end

  def initialize(locale)
    @locale = locale
  end

  def items
    Rails.cache.fetch("navigation_menu/#{self.class.cache_stamp}", expires_in: CACHE_TTL) { build }
  end

  private

  attr_reader :locale

  def build
    [
      new_item, gaming_pcs_item, gpus_item, children_item("components"),
      children_item("peripherals"), other_systems_item, simple_category_item("workstations"),
      more_item
    ].compact
  end

  # --- Top items ------------------------------------------------------------

  def new_item
    Item.new(
      key: "new", label: t(".new"),
      href: search_path(locale: locale, sort: "newest")
    )
  end

  def gaming_pcs_item
    category = find_category("gaming-pcs")
    return unless category

    columns = [
      column(t(".by_budget"), category: category, labels: BUDGET_LABELS["gaming_pcs"]),
      column(t(".popular_builds"), category: category, seller_tags: THEME_TAGS)
    ].compact
    Item.new(key: "gaming_pcs", label: category.name, href: category_path(category, locale: locale),
             columns: columns, promos: promos)
  end

  def gpus_item
    category = find_category("gpus")
    return unless category

    columns = [
      column(t(".by_brand"), category: category, chipsets: true),
      column(t(".by_budget"), category: category, labels: BUDGET_LABELS["gpus"])
    ].compact
    Item.new(key: "gpus", label: category.name, href: category_path(category, locale: locale),
             columns: columns, promos: promos)
  end

  def simple_category_item(slug)
    category = find_category(slug)
    return unless category

    Item.new(key: slug.tr("-", "_"), label: category.name,
             href: category_path(category, locale: locale))
  end

  def children_item(slug)
    category = find_category(slug)
    return unless category

    links = category.children.active.map { |child| category_link(child) }
    columns = links.size > 5 ? [ Column.new(links: links.first(links.size.fdiv(2).ceil)),
      Column.new(links: links.last(links.size.fdiv(2).floor)) ] : [ Column.new(links: links) ]
    Item.new(key: slug.tr("-", "_"), label: category.name,
             href: category_path(category, locale: locale),
             columns: columns.select { |c| c.links.any? }, promos: promos)
  end

  def other_systems_item
    laptops = find_category("laptops")
    columns = [
      column(t(".laptops_column"), slugs: [ "laptops" ]),
      column(t(".mobile_column"), slugs: %w[phones tablets]),
      column(t(".gaming_systems_column"), slugs: %w[consoles gaming-handhelds retro-consoles retro-handhelds])
    ].compact
    return if columns.empty?

    Item.new(key: "other_systems", label: t(".other_systems"),
             href: laptops ? category_path(laptops, locale: locale) : search_path(locale: locale),
             columns: columns)
  end

  def more_item
    columns = [
      children_column(t(".accessories_column"), "accessories"),
      children_column(t(".games_software_column"), "games-software")
    ].compact
    return if columns.empty?

    Item.new(key: "more", label: t(".more"),
             href: category_path(find_category("accessories") || Category.roots.first, locale: locale),
             columns: columns)
  end

  # --- Columns and links ------------------------------------------------------

  def column(title, category: nil, labels: [], chipsets: false, seller_tags: [], slugs: [])
    links = Array(slugs).filter_map { |slug| category_link(find_category(slug)) }
    links.concat(labels.filter_map { |slug| label_link(category, "labels", slug) })
    links.concat(seller_tags.filter_map { |slug| label_link(category, "seller_tags", slug) })
    links.concat(chipset_links(category)) if chipsets
    return if links.empty?

    Column.new(title: title, links: links)
  end

  def children_column(title, slug)
    category = find_category(slug)
    return unless category

    links = [ category_link(category) ] + category.children.active.map { |child| category_link(child) }
    Column.new(title: title, links: links.select(&:present?))
  end

  def chipset_links(category)
    FilterOption.joins(:filter_definition)
                .where(filter_definitions: { key: "gpu_chipset", active: true })
                .active.ordered
                .map do |option|
      Link.new(label: option.label,
               href: category_path(category, locale: locale, specs: { gpu_chipset: [ option.value ] }))
    end
  end

  def label_link(category, dimension, slug)
    return if category.nil?

    record = dimension == "labels" ? ProductLabel.active.find_by(slug: slug) : SellerTag.active.find_by(slug: slug)
    return unless record

    Link.new(label: record.name,
             href: category_path(category, locale: locale, dimension => [ slug ]))
  end

  def category_link(category)
    return if category.nil?

    Link.new(label: category.name, href: category_path(category, locale: locale))
  end

  def promos
    list = [
      Promo.new(key: "pc_finder", title: t(".pc_finder.title"), body: t(".pc_finder.body"),
                href: pc_finder_path(locale: locale))
    ]
    if AppSettings.enabled?(:sell_to_us_enabled)
      list << Promo.new(key: "sell_to_us", title: t(".sell_to_us.title"), body: t(".sell_to_us.body"),
                        href: sell_to_us_path(locale: locale))
    end
    list
  end

  # --- Lookups ----------------------------------------------------------------

  def find_category(slug)
    @categories ||= Category.active.includes(:children).index_by(&:slug)
    @categories[slug]
  end

  def t(key)
    I18n.t("navigation_menu#{key}", locale: locale)
  end
end
