class MenuBuilder
  CACHE_VERSION = "menu/v2"
  PRIMARY_LIMIT = 7

  def initialize(locale: I18n.locale)
    @locale = locale.to_s
  end

  def call
    Rails.cache.fetch(cache_key, expires_in: 12.hours) { build_menu }
  end

  private

  def self.bust!
    Rails.cache.write("menu/v2/version", Time.current.to_f)
  end

  def self.version
    Rails.cache.fetch("menu/v2/version", expires_in: 1.day) { 0.0 }
  end

  def cache_key
    [ CACHE_VERSION, @locale, self.class.version, Category.maximum(:updated_at)&.utc&.to_f ]
  end

  def build_menu
    roots = Category.menu_roots.to_a
    child_groups = Category.active
                           .where(ancestry: roots.map { |root| root.id.to_s })
                           .order(:position, :id)
                           .to_a
                           .group_by { |child| child.ancestry.to_s }

    roots.map do |root|
      {
        "id" => root.id,
        "name" => root.name(@locale),
        "slug" => root.slug,
        "icon" => root.icon,
        "path" => category_path([ root.slug ]),
        "children" => (child_groups[root.id.to_s] || []).map do |child|
          {
            "id" => child.id,
            "name" => child.name(@locale),
            "slug" => child.slug,
            "path" => category_path([ root.slug, child.slug ])
          }
        end
      }
    end
  end

  # Relative category URL that is stable across hosts and cache stores.
  def category_path(slugs)
    prefix = @locale == I18n.default_locale.to_s ? "" : "/#{@locale}"
    "#{prefix}/c/#{slugs.join('/')}"
  end
end
