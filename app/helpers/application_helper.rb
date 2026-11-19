module ApplicationHelper
  # Placeholder taxonomy until the catalog phase ships real categories.
  # Every entry links to the (placeholder) search with the category slug.
  def nav_categories
    [
      { slug: "desktops" },
      { slug: "laptops" },
      { slug: "components", children: %w[gpus cpus motherboards memory storage cooling] },
      { slug: "peripherals", children: %w[monitors keyboards mice headsets] },
      { slug: "phones" },
      { slug: "tablets" },
      { slug: "consoles" }
    ]
  end

  def category_label(slug)
    t("nav.categories.#{slug}")
  end

  def category_path(slug)
    search_path(q: slug)
  end

  def locale_label(locale)
    t("locales.#{locale}")
  end

  # Google sign-in is only shown once real credentials are configured.
  def google_oauth_enabled?
    ENV["GOOGLE_CLIENT_ID"].present? && ENV["GOOGLE_CLIENT_SECRET"].present?
  end
end
