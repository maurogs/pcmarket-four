class ListingsController < ApplicationController
  include SearchRendering

  before_action :authenticate_user!, only: %i[new create edit update destroy]

  def index
    @category = nil
    @search = ListingSearch.new(params: search_params)
    render_search
  end

  def show
    @listing = find_listing!
    return if performed?

    redirect_to_old_slug and return if @listing.nil?
    raise ActiveRecord::RecordNotFound unless @listing.viewable_by?(current_user)

    track_view
    load_listing_details
    set_listing_meta
    cache_listing_response
  end

  def new
  end

  def create
    redirect_to listings_path, notice: t("pages.coming_soon.default_body")
  end

  def edit
  end

  def update
    redirect_to listing_path(params[:id]), notice: t("pages.coming_soon.default_body")
  end

  def destroy
    redirect_to listings_path, notice: t("pages.coming_soon.default_body")
  end

  private

  def find_listing!
    Listing
      .includes(:store, :user, :category, :region, { images_attachments: :blob })
      .find_by(slug: params[:id])
  end

  def redirect_to_old_slug
    slug = FriendlyId::Slug.find_by(slug: params[:id], sluggable_type: "Listing")
    raise ActiveRecord::RecordNotFound if slug.nil?

    listing = Listing.find_by(id: slug.sluggable_id)
    raise ActiveRecord::RecordNotFound if listing.nil?

    redirect_to listing_path(listing), status: :moved_permanently
  end

  def track_view
    return if bot_request?
    return if current_user && current_user.id == @listing.user_id

    seen = Array(session[:viewed_listing_ids])
    return if seen.include?(@listing.id)

    Listing.register_view!(@listing.id)
    @listing.views_count += 1
    session[:viewed_listing_ids] = (seen << @listing.id).last(50)
  end

  def bot_request?
    ua = request.user_agent.to_s.downcase
    ua.blank? || ua.match?(/bot|crawl|spider|slurp|bingpreview|headless|python|curl|wget/)
  end

  def load_listing_details
    @store = @listing.store
    @spec_labels = FilterDefinition.where(key: @listing.specs.keys).index_by(&:key)
    @option_labels = FilterOption
                     .where(filter_definition_id: @spec_labels.values.map(&:id))
                     .index_by { |option| [ option.filter_definition_id, option.value ] }
    @effective_filters = @listing.category.effective_filters
    @favorite = current_user&.favorites&.find_by(listing_id: @listing.id)
    @reviews = @store ? @store.reviews.where(published: true).includes(:reviewer)
                             .order(created_at: :desc).limit(5).to_a : []
    @similar_listings = similar_listings
    @more_from_seller = more_from_seller
    @recently_viewed = recently_viewed
    @games = Game.where(slug: @listing.game_fps.keys).index_by(&:slug)

    listings = [ @listing ] + @similar_listings + @more_from_seller + @recently_viewed
    if current_user
      @favorite_ids_by_listing = current_user.favorites
                                              .where(listing_id: listings.map(&:id))
                                              .pluck(:id, :listing_id).to_h
      @favorited_listing_ids = @favorite_ids_by_listing.keys.to_set
    else
      @favorite_ids_by_listing = {}
      @favorited_listing_ids = Set.new
    end
  end

  def similar_listings
    Rails.cache.fetch([ "similar", @listing.id, @listing.category_id, @listing.price_cents ],
                      expires_in: 10.minutes) do
      Listing.similar_to(@listing)
             .includes(:store, :category, :region, :user, { images_attachments: :blob })
             .to_a
    end
  end

  def more_from_seller
    return [] if @store.nil?

    @store.listings.visible
          .includes(:store, :category, :region, :user, { images_attachments: :blob })
          .where.not(id: @listing.id)
          .recent.limit(8).to_a
  end

  def recently_viewed
    ids = Array(session[:viewed_listing_ids]).reverse - [ @listing.id ]
    return [] if ids.empty?

    found = Listing.visible.includes(:store, :category, :region, :user,
                                     { images_attachments: :blob })
                    .where(id: ids).index_by(&:id)
    ids.filter_map { |id| found[id] }.first(12)
  end

  def set_listing_meta
    description = ActionController::Base.helpers.strip_tags(@listing.description.to_s)
                                              .squish.first(160)
    set_meta_tags(
      title: t("listings.show.meta_title", title: @listing.title,
               price: view_context.format_price(@listing.price_cents)),
      description: description,
      canonical: listing_url(@listing, locale: I18n.locale),
      reverse: true,
      separator: " | ",
      og: {
        type: "product",
        title: @listing.title,
        description: description,
        url: listing_url(@listing, locale: I18n.locale),
        image: listing_image_url(@listing)
      },
      product: {
        price: format("%.2f", @listing.price_cents / 100.0),
        currency: @listing.currency
      }
    )
    @listing_json_ld = view_context.listing_structured_data(@listing)
    @breadcrumbs = view_context.breadcrumbs_for_listing(@listing)
  end

  def cache_listing_response
    return if user_signed_in? || !request.get?

    expires_in 5.minutes, public: true
    fresh_when(
      etag: [ @listing, I18n.locale, @store&.updated_at&.to_i ],
      public: true
    )
  end

  def listing_image_url(listing)
    return nil unless listing.images.attached?

    url_for(listing.images.first.variant(resize_to_limit: [ 1200, 900 ], format: :webp),
            only_path: false)
  rescue StandardError
    nil
  end
end
