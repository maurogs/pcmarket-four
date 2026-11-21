class PagesController < ApplicationController
  before_action :set_page_key

  def sell
  end

  def trust
    @trust_stats = TrustStats.call
    set_meta_tags(
      title: t("content.trust.title"),
      description: t("content.trust.meta_description")
    )
  end

  def about
    set_meta_tags(
      title: t("content.about.title"),
      description: t("content.about.meta_description")
    )
  end

  private

  def set_page_key
    @page_key = action_name
  end
end
