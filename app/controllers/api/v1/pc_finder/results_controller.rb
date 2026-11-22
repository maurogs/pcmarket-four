module Api
  module V1
    module PcFinder
      class ResultsController < BaseController
        PER_PAGE = 12

        def index
          recommender = ::PcFinder::Recommender.new(
            games: params[:games],
            resolution: params[:resolution],
            fps: params[:fps],
            budget: params[:budget],
            case_colour: params[:case],
            cooling: params[:cooling],
            vibes: params[:vibe],
            sort: params[:sort]
          )

          results = recommender.results
          @listings = Listing.where(id: results.map(&:listing_id))
                             .includes(:store, :category, images_attachments: :blob)
                             .index_by(&:id)
          results = sort_results(results, recommender.sort)

          page = [ params[:page].to_i, 1 ].max
          pages = [ (results.size.to_f / PER_PAGE).ceil, 1 ].max
          page = [ page, pages ].min
          @pagy = Pagy.new(count: results.size, page: page, limit: PER_PAGE)
          @results = results.slice(@pagy.offset, PER_PAGE) || []

          render :index, formats: :json
        end

        private

        def sort_results(results, sort)
          case sort
          when "price_asc"
            results.sort_by { |result| @listings[result.listing_id]&.price_cents.to_i }
          when "price_desc"
            results.sort_by { |result| -@listings[result.listing_id]&.price_cents.to_i }
          else
            results.sort_by { |result| -result.score }
          end
        end
      end
    end
  end
end
