class MenuBuilder
  CACHE_VERSION = "menu/v1"

  def initialize(locale: I18n.locale)
    @locale = locale.to_s
  end

  def call
    Rails.cache.fetch(cache_key, expires_in: 12.hours) { build_menu }
  end

  private

  def cache_key
    [ CACHE_VERSION, @locale, Category.maximum(:updated_at)&.utc&.to_f ]
  end

  def build_menu
    Category.menu_roots.map do |root|
      {
        "id" => root.id,
        "name" => root.name(@locale),
        "slug" => root.slug,
        "icon" => root.icon,
        "path" => category_path(root.path_slugs),
        "children" => root.children.active.order(:position, :id).map do |child|
          {
            "id" => child.id,
            "name" => child.name(@locale),
            "slug" => child.slug,
            "path" => category_path(child.path_slugs)
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
