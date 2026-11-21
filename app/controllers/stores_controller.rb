class StoresController < ApplicationController
  include SearchRendering

  TABS = %w[listings about reviews].freeze
  REVIEW_SORTS = %w[newest highest lowest].freeze

  def show
    @store = Store.friendly.find(params[:id])
    @tab = TABS.include?(params[:tab]) ? params[:tab] : "listings"
    load_store_counters

    case @tab
    when "about"
      render_tab("stores/tabs/about")
    when "reviews"
      load_reviews
      render_tab("stores/tabs/reviews")
    else
      load_store_listings
      set_store_meta
      render_search(search_meta: false, cache: false, partial: "stores/tabs/listings")
    end
  end

  private

  def load_store_counters
    @follow = current_user&.follows&.find_by(store_id: @store.id)
    @for_sale_count = @store.listings.visible.count
    @sold_count = @store.listings.sold.count
    @rating_distribution = @store.reviews.where(published: true).group(:rating).count
  end

  def load_store_listings
    @include_sold = ActiveModel::Type::Boolean.new.cast(params[:include_sold]) == true
    base = if @include_sold
      Listing.storefront.where(store_id: @store.id)
    else
      Listing.visible.where(store_id: @store.id)
    end

    category = Category.find_by(id: params[:category_id]) if params[:category_id].present?
    @store_categories = Category.active
                                .where(id: @store.listings.select(:category_id))
                                .order(:position, :id)
    @search = ListingSearch.new(params: search_params, category: category, base: base)
  end

  def load_reviews
    sort = REVIEW_SORTS.include?(params[:review_sort]) ? params[:review_sort] : "newest"
    scope = @store.reviews.where(published: true).includes(:reviewer)
    scope = case sort
    when "highest" then scope.order(rating: :desc, created_at: :desc)
    when "lowest" then scope.order(rating: :asc, created_at: :desc)
    else scope.order(created_at: :desc)
    end
    @pagy_reviews, @reviews = pagy(scope, limit: 10)
    @review_sort = sort
    @reviews_count = @store.reviews.where(published: true).count
  end

  def render_tab(partial)
    set_store_meta
    return unless turbo_frame_request?

    render partial: partial, layout: false
  end

  def set_store_meta
    description = @store.description.presence ||
                  t("stores.meta.description", store: @store.name)
    set_meta_tags(
      title: t("stores.meta.title", store: @store.name),
      description: description.to_s.squish.first(160),
      canonical: store_url(@store, locale: I18n.locale),
      reverse: true,
      separator: " | ",
      og: {
        type: "website",
        title: @store.name,
        description: description.to_s.squish.first(160),
        url: store_url(@store, locale: I18n.locale)
      }
    )
    @store_json_ld = view_context.store_structured_data(@store)
  end
end
