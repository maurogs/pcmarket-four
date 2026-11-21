require "builder"

class SitemapBuilder
  MAX_URLS = 45_000

  Entry = Data.define(:suffix, :lastmod)

  def initialize(host:, page: nil)
    @host = host.to_s.sub(%r{/\z}, "")
    @page = page.to_i.positive? ? page.to_i : nil
  end

  def index?
    entries.size > MAX_URLS && @page.nil?
  end

  def index
    xml = Builder::XmlMarkup.new(indent: 2)
    xml.instruct! :xml, version: "1.0", encoding: "UTF-8"
    xml.sitemapindex("xmlns" => "http://www.sitemaps.org/schemas/sitemap/0.9") do
      page_count.times do |index|
        xml.sitemap do
          xml.loc "#{@host}/sitemap.xml?page=#{index + 1}"
          xml.lastmod newest_change.utc.iso8601
        end
      end
    end
  end

  def render
    xml = Builder::XmlMarkup.new(indent: 2)
    xml.instruct! :xml, version: "1.0", encoding: "UTF-8"
    xml.urlset(
      "xmlns" => "http://www.sitemaps.org/schemas/sitemap/0.9",
      "xmlns:xhtml" => "http://www.w3.org/1999/xhtml"
    ) do
      page_entries.each do |entry|
        xml.url do
          xml.loc absolute_url(:es, entry.suffix)
          xml.lastmod entry.lastmod.utc.iso8601
          alternates_for(entry.suffix).each do |hreflang, href|
            xml.tag!("xhtml:link", rel: "alternate", hreflang: hreflang, href: href)
          end
        end
      end
    end
  end

  private

  def page_count
    (entries.size / MAX_URLS.to_f).ceil
  end

  def page_entries
    return entries if entries.size <= MAX_URLS

    start = ((@page || 1) - 1) * MAX_URLS
    entries[start, MAX_URLS] || []
  end

  def alternates_for(suffix)
    I18n.available_locales.each_with_object({}) do |locale, hash|
      hash[locale.to_s] = absolute_url(locale, suffix)
    end.merge("x-default" => absolute_url(:es, suffix))
  end

  def absolute_url(locale, suffix)
    "#{@host}/#{locale}#{suffix}"
  end

  def newest_change
    @newest_change ||= entries.filter_map(&:lastmod).max || Time.current
  end

  def entries
    @entries ||= begin
      now = Time.current
      rows = [
        Entry.new("", now),
        Entry.new("/about", now),
        Entry.new("/help", now),
        Entry.new("/trust", now),
        Entry.new("/sell", now),
        Entry.new("/pc-finder", now)
      ]

      Category.active.find_each do |category|
        rows << Entry.new("/c/#{category.path_slugs.join('/')}", category.updated_at)
      end

      Listing.visible.includes(:store).find_each do |listing|
        rows << Entry.new("/l/#{listing.slug}", listing.updated_at)
      end

      Store.find_each do |store|
        rows << Entry.new("/s/#{store.slug}", store.updated_at)
      end

      LegalPage.published.find_each do |page|
        rows << Entry.new("/legal/#{page.slug}", page.updated_at)
      end

      HelpArticle.published.find_each do |article|
        rows << Entry.new("/help/#{article.slug}", article.updated_at)
      end

      rows
    end
  end
end
