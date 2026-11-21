module Seller
  class StoresController < BaseController
    def edit
      @store = seller_store
      load_location_options
    end

    def update
      @store = seller_store
      @store.assign_attributes(store_params)

      if @store.save
        redirect_to edit_seller_store_path,
                    notice: t("seller.store_profile.saved")
      else
        load_location_options
        render :edit, status: :unprocessable_entity
      end
    end

    private

    def load_location_options
      @countries = Country.enabled.order(:code)
      @regions = Region.order(:name)
    end

    def store_params
      params.require(:store).permit(
        :name, :description, :store_type, :company_name, :tax_id,
        :country_code, :region_id, :city, :logo, :banner
      )
    end
  end
end
