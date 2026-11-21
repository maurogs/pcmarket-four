module Account
  class AddressesController < BaseController
    before_action :set_address, only: %i[edit update destroy]
    before_action :load_location_options, only: %i[new create edit update]

    def index
      @addresses = current_user.addresses.ordered
    end

    def new
      @address = current_user.addresses.build(country_code: current_user.country_code)
    end

    def create
      @address = current_user.addresses.build(address_params)

      if @address.save
        redirect_to account_addresses_path, notice: t("account.addresses.created")
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @address.update(address_params)
        redirect_to account_addresses_path, notice: t("account.addresses.updated")
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @address.destroy!
      redirect_to account_addresses_path, notice: t("account.addresses.destroyed")
    end

    private

    def set_address
      @address = current_user.addresses.find(params[:id])
    end

    def load_location_options
      @countries = Country.enabled.order(:code)
      @regions = Region.order(:name)
    end

    def address_params
      params.require(:address).permit(
        :full_name, :line1, :line2, :city, :postal_code,
        :region_id, :country_code, :phone, :default
      )
    end
  end
end
