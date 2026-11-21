class LegalPagesController < ApplicationController
  prepend_before_action :set_legal_context, only: :show

  def show
    @legal_pages = LegalPage.published
                             .for_country(@country.code)
                             .for_locale(@legal_page.locale)
                             .to_a
                             .sort_by { |page| LegalPage::SLUGS.index(page.slug) || LegalPage::SLUGS.size }
    set_legal_meta_tags
  end

  private

  def set_legal_context
    @country = market_country
    raise ActiveRecord::RecordNotFound if @country.nil?

    @legal_page = LegalPage.resolve(country: @country, locale: I18n.locale, slug: params[:slug])
    raise ActiveRecord::RecordNotFound if @legal_page.nil?
  end

  # The default head uses every enabled locale. Legal pages only advertise the
  # locales that actually exist for this country and slug.
  def alternate_urls
    return super unless defined?(@legal_page) && @legal_page && @country

    legal_alternates
  end

  def set_legal_meta_tags
    description = ActionController::Base.helpers.strip_tags(@legal_page.rendered_body.to_s)
                                                    .squish.first(160)
    set_meta_tags(
      title: @legal_page.title,
      description: description,
      canonical: legal_page_url_for(@legal_page.locale)
    )
  end

  def legal_alternates
    alternates = LegalPage.available_locales_for(
      country_code: @country.code, slug: @legal_page.slug
    ).index_with { |locale| legal_page_url_for(locale) }
    alternates.merge("x-default" => legal_page_url_for(@legal_page.locale))
  end

  def legal_page_url_for(locale)
    options = { locale: locale, only_path: false }
    options[:country] = @country.code unless @country.code == "ES"
    legal_page_url(@legal_page.slug, **options)
  end
end
