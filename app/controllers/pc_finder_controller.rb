class PcFinderController < ApplicationController
  def show
    @landing = PcFinder::Landing.call
    @games = Game.visible
    @budgets = PcFinder::Recommender::BUDGETS
    @resolutions = PcFinder::Recommender::RESOLUTIONS
    @fps_targets = PcFinder::Recommender::FPS_TARGETS

    set_meta_tags(
      title: t("pc_finder.meta.title"),
      description: t("pc_finder.meta.description"),
      canonical: "#{request.base_url}#{request.path}",
      robots: "index,follow"
    )
  end
end
