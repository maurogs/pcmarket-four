class SeoController < ApplicationController
  layout false
  skip_before_action :set_default_meta_tags

  def robots
    render :robots, formats: :text
  end

  def sitemap
    builder = SitemapBuilder.new(host: request.base_url, page: params[:page])
    xml = Rails.cache.fetch(cache_key, expires_in: 1.hour) do
      builder.index? ? builder.index : builder.render
    end
    render xml: xml, content_type: "application/xml"
  end

  private

  def cache_key
    [
      "sitemap/v1", request.base_url, params[:page].to_s,
      Category.maximum(:updated_at)&.to_i,
      Listing.maximum(:updated_at)&.to_i,
      Store.maximum(:updated_at)&.to_i,
      LegalPage.maximum(:updated_at)&.to_i,
      HelpArticle.maximum(:updated_at)&.to_i
    ]
  end
end
