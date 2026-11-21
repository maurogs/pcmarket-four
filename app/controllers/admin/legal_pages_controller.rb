module Admin
  class LegalPagesController < BaseController
    before_action :set_page, only: %i[show edit update destroy]

    def index
      authorize_admin!(LegalPage, :index?)

      @pages = filtered_scope.includes(:updated_by).order(:country_code, :slug, :locale)
      @countries = Country.order(:code)
    end

    def show
      authorize_admin!(@page, :show?)
      redirect_to edit_admin_legal_page_path(id: @page.id)
    end

    def new
      authorize_admin!(LegalPage, :new?)

      @page = LegalPage.new(published: false, locale: I18n.locale)
    end

    def create
      authorize_admin!(LegalPage, :create?)

      @page = LegalPage.new(page_params)
      @page.updated_by = current_user
      if @page.save
        audit!("legal_page.created", @page)
        redirect_to edit_admin_legal_page_path(@page), notice: t("admin.legal_pages.created")
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      authorize_admin!(@page, :edit?)

      @copy_sources = LegalPage.where.not(id: @page.id).order(:country_code, :slug, :locale)
      if params[:copy_from].present?
        source = LegalPage.find_by(id: params[:copy_from])
        if source
          @page.title = source.title
          @page.body = source.body
        end
      end
    end

    def update
      authorize_admin!(@page, :update?)

      @page.updated_by = current_user
      if @page.update(page_params)
        audit!("legal_page.updated", @page)
        redirect_to edit_admin_legal_page_path(@page), notice: t("admin.legal_pages.updated")
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      authorize_admin!(@page, :destroy?)

      @page.destroy!
      audit!("legal_page.deleted", @page, changeset: { "slug" => @page.slug })
      redirect_to admin_legal_pages_path, notice: t("admin.legal_pages.deleted")
    end

    private

    def set_page
      @page = LegalPage.find_by(id: params[:id]) || LegalPage.find_by!(slug: params[:id])
    end

    def filtered_scope
      scope = LegalPage.all
      scope = scope.where(country_code: params[:country_code]) if params[:country_code].present?
      scope = scope.where(locale: params[:locale]) if params[:locale].present?
      scope = scope.where(slug: params[:slug]) if params[:slug].present?
      scope
    end

    def page_params
      params.require(:legal_page).permit(:slug, :country_code, :locale, :title, :body,
                                         :published)
    end
  end
end
