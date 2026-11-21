module Admin
  class RegionsController < BaseController
    before_action :set_country
    before_action :set_region, only: %i[update destroy]

    def index
      authorize_admin!(Region, :index?)

      @regions = @country.regions.order(:name)
    end

    def create
      authorize_admin!(Region, :create?)

      region = @country.regions.new(region_params)
      if region.save
        audit!("region.created", region)
        redirect_to admin_country_regions_path(@country), notice: t("admin.countries.regions.created")
      else
        redirect_to admin_country_regions_path(@country), alert: t("admin.countries.regions.invalid")
      end
    end

    def update
      authorize_admin!(@region, :update?)

      if @region.update(region_params)
        audit!("region.updated", @region)
        redirect_to admin_country_regions_path(@country), notice: t("admin.countries.regions.updated")
      else
        redirect_to admin_country_regions_path(@country), alert: t("admin.countries.regions.invalid")
      end
    end

    def destroy
      authorize_admin!(@region, :destroy?)

      name = @region.name
      @region.destroy!
      audit!("region.deleted", @country, changeset: { "name" => name })
      redirect_to admin_country_regions_path(@country), notice: t("admin.countries.regions.deleted")
    end

    private

    def set_country
      @country = Country.find(params[:country_id])
    end

    def set_region
      @region = @country.regions.find(params[:id])
    end

    def region_params
      params.require(:region).permit(:name, :code)
    end
  end
end
