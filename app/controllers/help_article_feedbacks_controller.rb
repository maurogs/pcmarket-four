class HelpArticleFeedbacksController < ApplicationController
  def create
    article = HelpArticle.published.find_by!(slug: params[:help_article_slug])
    helpful = params[:helpful].to_s.in?(%w[yes true 1])
    HelpArticleFeedback.record!(
      article: article,
      session_id: help_feedback_session_id,
      helpful: helpful
    )
    redirect_to help_article_path(article, anchor: "feedback"),
                notice: t("content.help.feedback.thanks")
  end
end
