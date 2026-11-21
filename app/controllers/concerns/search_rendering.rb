# Shared rendering pipeline for listing index, category and store pages.
# Controllers only resolve the category/store context and pass permitted
# params to ListingSearch.
module SearchRendering
  extend ActiveSupport::Concern

  private

  def render_search(search_meta: true, cache: true, partial: "listings/results")
    @result = @search.result
    @pagy = @result.pagy
    @listings = @result.listings
    @favorite_ids_by_listing = favorite_ids_by_listing(@listings)
    @favorited_listing_ids = @favorite_ids_by_listing.keys.to_set
    cache_search_response if cache
    set_search_meta if search_meta

    return unless turbo_frame_request?

    render partial: partial, layout: false
  end

  def favorite_ids_by_listing(listings)
    return {} unless current_user

    current_user.favorites.where(listing_id: listings.map(&:id)).pluck(:id, :listing_id).to_h
  end

  def cache_search_response
    return if user_signed_in? || !request.get? || turbo_frame_request?

    expires_in 60.seconds, public: true
    fresh_when(
      etag: [ "search", I18n.locale, @search.digest, Listing.maximum(:updated_at)&.to_i ],
      public: true
    )
  end

  def set_search_meta
    count = @result.total_count
    if @category
      title = t("search.meta.category_title", category: @category.name, count: count)
      description = @category.seo_descriptions[I18n.locale.to_s].presence ||
                    @category.seo_descriptions["es"].presence ||
                    t("search.meta.category_description", category: @category.name)
    else
      title = if @search.query.present?
        t("search.meta.query_title", query: @search.query)
      else
        t("search.meta.title")
      end
      description = t("search.meta.description")
    end

    set_meta_tags(
      title: title,
      description: description,
      canonical: "#{request.base_url}#{request.path}",
      robots: indexable_search? ? "index,follow" : "noindex,follow",
      reverse: true,
      separator: " | "
    )
    set_search_pagination_links
    @search_json_ld = view_context.search_structured_data
  end

  def indexable_search?
    !filters_applied? && @search.page == 1
  end

  def set_search_pagination_links
    @pagination_links = [
      (@result.pagy.prev ? search_page_url(@result.pagy.prev, rel: "prev") : nil),
      (@result.pagy.next ? search_page_url(@result.pagy.next, rel: "next") : nil)
    ].compact
  end

  def search_page_url(page, rel:)
    path = @category ? category_path(path: @category.path_slugs) : search_path
    query = search_params.to_h.except("page").to_query
    href = "#{request.base_url}#{path}#{query.present? ? "?#{query}&" : '?'}page=#{page}"
    view_context.tag.link(rel: rel, href: href)
  end
end
