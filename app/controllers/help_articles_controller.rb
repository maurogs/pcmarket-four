class HelpArticlesController < ApplicationController
  def index
    @query = params[:q].to_s.squish
    @category = HelpArticle::CATEGORIES.include?(params[:category].to_s) ? params[:category].to_s : nil

    scope = @query.present? ? HelpArticle.search(@query, locale: I18n.locale) : HelpArticle.published
    scope = scope.for_category(@category) if @category
    @articles = scope.ordered
    @popular = HelpArticle.popular
    @category_counts = HelpArticle.published.group(:category).count
    @category_counts = HelpArticle::CATEGORIES.index_with do |category|
      @category_counts[category] || @category_counts[HelpArticle.categories[category]] || 0
    end
    @feedback_counts = HelpArticleFeedback.group(:helpful).count
    set_meta_tags(
      title: t("content.help.index.title"),
      description: t("content.help.index.meta_description")
    )
  end

  def show
    @article = HelpArticle.published.find_by!(slug: params[:slug])
    @related = HelpArticle.published
                          .for_category(@article.category)
                          .where.not(id: @article.id)
                          .ordered
                          .limit(4)
    @feedback = @article.help_article_feedbacks.find_by(session_id: help_feedback_session_id)
    set_meta_tags(
      title: @article.title,
      description: ActionController::Base.helpers.strip_tags(@article.body_html.to_s).squish.first(160)
    )
  end
end
