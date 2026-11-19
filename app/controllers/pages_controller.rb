class PagesController < ApplicationController
  # Static information pages rendered from the locale files. RESTful show
  # action; the id is the page key and must be allowlisted.
  PAGES = %w[about help buying-selling selling seller-academy
             terms privacy cookies trust].freeze

  before_action :set_page

  def show
    # Renders app/views/pages/show.html.erb with the localized content.
  end

  private

  def set_page
    raise ActiveRecord::RecordNotFound unless PAGES.include?(params[:id])
  end
end
