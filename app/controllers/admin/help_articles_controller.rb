module Admin
  class HelpArticlesController < BaseController
    before_action :set_article, only: %i[show edit update destroy]

    def index
      authorize_admin!(HelpArticle, :index?)

      @articles = HelpArticle.ordered
    end

    def show
      authorize_admin!(@article, :show?)
      redirect_to edit_admin_help_article_path(@article)
    end

    def new
      authorize_admin!(HelpArticle, :new?)

      @article = HelpArticle.new(published: true, position: HelpArticle.maximum(:position).to_i + 1)
    end

    def create
      authorize_admin!(HelpArticle, :create?)

      @article = HelpArticle.new(article_params)
      if @article.save
        audit!("help_article.created", @article)
        redirect_to edit_admin_help_article_path(@article), notice: t("admin.help_articles.created")
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      authorize_admin!(@article, :edit?)
    end

    def update
      authorize_admin!(@article, :update?)

      if @article.update(article_params)
        audit!("help_article.updated", @article)
        redirect_to edit_admin_help_article_path(@article), notice: t("admin.help_articles.updated")
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      authorize_admin!(@article, :destroy?)

      @article.destroy!
      audit!("help_article.deleted", @article, changeset: { "slug" => @article.slug })
      redirect_to admin_help_articles_path, notice: t("admin.help_articles.deleted")
    end

    private

    def set_article
      @article = HelpArticle.find_by(slug: params[:id]) || HelpArticle.find(params[:id])
    end

    def article_params
      permitted = params.require(:help_article).permit(
        :slug, :category, :position, :published,
        titles: I18n.available_locales.map(&:to_s),
        bodies: I18n.available_locales.map(&:to_s)
      )
      permitted[:titles] = (permitted[:titles] || {}).to_h.compact_blank
      permitted[:bodies] = (permitted[:bodies] || {}).to_h.compact_blank
      permitted
    end
  end
end
