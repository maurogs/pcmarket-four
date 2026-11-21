module Admin
  class PlaceholdersController < BaseController
    SECTIONS = %w[orders disputes reports reviews categories filters legal-pages games
                  newsletter settings countries].freeze

    def show
      authorize_admin!(:placeholder, :show?)

      @section = params[:section].to_s
      head :not_found unless SECTIONS.include?(@section)
    end
  end
end
