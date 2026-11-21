class PagesController < ApplicationController
  before_action :set_page_key

  def sell
    @featured_stores = Store.where(verified: true)
                            .where("sales_count > 0")
                            .order(sales_count: :desc)
                            .limit(6)
    @recently_sold = Listing.recently_sold.includes(:store, images_attachments: :blob).limit(4)
    @academy_articles = HelpArticle.published.for_category("selling").ordered.limit(3)
    set_meta_tags(
      title: t("sell_page.meta.title"),
      description: t("sell_page.meta.description")
    )
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
