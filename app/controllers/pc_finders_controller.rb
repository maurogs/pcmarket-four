# GET /pc-finder — PC Finder quiz and gaming-PC recommendations (PcFinder services).
class PcFindersController < ApplicationController
  def show
    @query = PcFinder::Query.new(params)
    @result = PcFinder::Recommender.new(@query).call if @query.present?
    @games = Game.active.with_attached_image
  end
end
