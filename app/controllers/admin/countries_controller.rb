module Admin
  class CountriesController < BaseController
    before_action :set_country, only: :update

    def index
      authorize_admin!(Country, :index?)

      @countries = Country.order(:code)
      @listing_counts = Listing.group(:country_code).count
      @user_counts = User.group(:country_code).count
      @checklists = @countries.index_with { |country| Admin::CountryLaunchChecklist.new(country) }
    end

    def update
      authorize_admin!(Country, :update?)

      enabling = ActiveModel::Type::Boolean.new.cast(country_params[:enabled])
      if enabling && !@country.enabled?
        checklist = Admin::CountryLaunchChecklist.new(@country)
        if checklist.blocked_reason == "currency"
          redirect_to admin_countries_path,
                      alert: t("admin.countries.currency_blocked", currency: @country.currency)
          return
        end
      end

      if @country.update(country_params)
        audit!("country.updated", @country)
        redirect_to admin_countries_path,
                    notice: t("admin.countries.updated", name: @country.name)
      else
        redirect_to admin_countries_path, alert: t("admin.countries.cannot_update")
      end
    end

    private

    def set_country
      @country = Country.find(params[:id])
    end

    def country_params
      params.require(:country).permit(:enabled, :currency, :vat_rate, :default_locale)
    end
  end
end
