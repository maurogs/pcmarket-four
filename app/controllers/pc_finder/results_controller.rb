module PcFinder
  class ResultsController < ApplicationController
    PER_PAGE = 12

    def index
      @recommender = Recommender.new(**recommender_params)
      @games = Game.where(slug: @recommender.games).index_by(&:slug)
      @results = @recommender.results
      @listings = Listing.where(id: @results.map(&:listing_id))
                         .includes(:store, :category, images_attachments: :blob)
                         .index_by(&:id)
      @results = sorted_results(@results)
      @pagy = Pagy.new(count: @results.size, page: page_number, limit: PER_PAGE)
      @page_results = @results.slice(@pagy.offset, PER_PAGE) || []
      @favorite_listing_ids = current_user ? current_user.favorites.where(listing_id: @listings.keys).pluck(:listing_id).to_set : Set.new

      set_meta_tags(
        title: t("pc_finder.results.meta_title", games: game_names_title),
        description: t("pc_finder.results.meta_description"),
        robots: "noindex,follow"
      )
    end

    private

    def recommender_params
      {
        games: params[:games],
        resolution: params[:resolution],
        fps: params[:fps],
        budget: params[:budget],
        case_colour: params[:case],
        cooling: params[:cooling],
        vibes: params[:vibe],
        sort: params[:sort]
      }
    end

    def page_number
      page = params[:page].to_i
      page.positive? ? page : 1
    end

    def sorted_results(results)
      case @recommender.sort
      when "price_asc"
        results.sort_by { |result| @listings&.fetch(result.listing_id, nil)&.price_cents.to_i }
      when "price_desc"
        results.sort_by { |result| -@listings&.fetch(result.listing_id, nil)&.price_cents.to_i }
      else
        results.sort_by { |result| -result.score }
      end
    end

    def game_names_title
      return t("pc_finder.results.all_games") if @recommender.games.empty?

      @games.values.map(&:name).join(", ")
    end
  end
end
