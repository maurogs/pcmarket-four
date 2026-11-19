# GET /s/:slug — public seller storefront (tabs: Listings / About / Reviews).
class StoresController < ApplicationController
  include Browseable

  REVIEWS_PER_PAGE = 10

  before_action :set_store

  def show
    return redirect_to(store_path(@store), status: :moved_permanently) if outdated_slug?

    @tab = params[:tab].to_s.presence_in(%w[listings about reviews]) || "listings"
    case @tab
    when "listings" then run_search(store: @store)
    when "reviews" then load_reviews
    end
  end

  private

  def set_store
    @store = Store.find_by_param(params[:slug])
    render_not_found unless @store
  end

  # FriendlyId history: old slugs 301 to the canonical one.
  def outdated_slug?
    @store.slug != params[:slug].to_s
  end

  # Published reviews, newest first, paginated for the reviews tab.
  def load_reviews
    scope = @store.reviews.published.recent.includes(author: { avatar_attachment: :blob })
    @pagy = Pagy::Offset.new(count: scope.count, page: [ params[:page].to_i, 1 ].max, limit: REVIEWS_PER_PAGE)
    @reviews = scope.offset(@pagy.offset).limit(@pagy.limit)
  end
end
