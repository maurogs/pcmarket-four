module LegalSeed
  module_function

  # Builds a consistent legal document. Sections are [heading, content] pairs;
  # content may be a paragraph string or an array rendered as a bullet list.
  def body(intro, sections)
    parts = [ "<p>#{intro}</p>" ]
    sections.each do |heading, content|
      parts << "<h2>#{heading}</h2>"
      parts << if content.is_a?(Array)
        "<ul>#{content.map { |item| "<li>#{item}</li>" }.join}</ul>"
      else
        content
      end
    end
    parts.join("\n")
  end

  def page(title, intro, sections)
    { title: title, body: body(intro, sections) }
  end
end

LEGAL_PAGE_CONTENT = {} unless defined?(LEGAL_PAGE_CONTENT)

Dir[Rails.root.join("db/seeds/legal/*.rb")].sort.each { |file| load file }

LEGAL_PAGE_CONTENT.each do |country_code, locales|
  locales.each do |locale, pages|
    pages.each do |slug, attributes|
      page = LegalPage.find_or_initialize_by(
        slug: slug.to_s, country_code: country_code, locale: locale.to_s
      )
      if page.persisted? && (page.version.to_i != 1 || page.updated_by_id.present?)
        next
      end

      page.assign_attributes(
        title: attributes.fetch(:title),
        body: attributes.fetch(:body),
        published: true
      )
      page.version = 1 if page.new_record?
      page.save!
    end
  end
end
