# Shared browse pipeline for category and search pages: build the params
# hash and hand everything to Listings::Search.
module Browseable
  extend ActiveSupport::Concern

  private

  def run_search(category: nil)
    @query = params[:q].to_s.strip
    search_params = params.permit(
      :sort, :page, :per_page, :min_price, :max_price,
      condition: [], labels: [], seller_tags: [], specs: {}
    )
    @search_result = Listings::Search.call(search_params.merge(q: @query, category: category&.slug))
  end

  def render_not_found
    render file: Rails.public_path.join("404.html"), status: :not_found, layout: false
  end
end
