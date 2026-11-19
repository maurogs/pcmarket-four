require "sitemap_generator"

SitemapGenerator::Sitemap.default_host =
  ENV.fetch("SITEMAP_HOST", "https://pcmarket.example")
SitemapGenerator::Sitemap.create_index = true
SitemapGenerator::Sitemap.sitemaps_path = "sitemaps"

SitemapGenerator::Sitemap.create do
  # One sitemap per locale with hreflang alternates.
  I18n.available_locales.each do |locale|
    add root_path(locale: locale), priority: 1.0, changefreq: "daily", lang: locale
    PagesController::PAGES.each do |page|
      add page_path(id: page, locale: locale), priority: 0.5, changefreq: "weekly", lang: locale
    end
  end

  # Listings, categories and other dynamic content join this file in later phases.
end
