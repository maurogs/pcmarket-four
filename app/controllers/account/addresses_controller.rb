# Signed-in shipping address book: /:locale/account/addresses.
# Everything is scoped to current_user.addresses — other users' rows 404.
module Account
  class AddressesController < ApplicationController
    before_action :authenticate_user!
    before_action :set_address, only: %i[edit update destroy]

    def index
      @addresses = current_user.addresses.defaults_first
    end

    def new
      @address = current_user.addresses.new(country: Current.country || current_user.country)
    end

    def edit; end

    def create
      @address = current_user.addresses.new(address_params)

      if @address.save
        redirect_to account_addresses_path, notice: t(".success")
      else
        render :new, status: :unprocessable_entity
      end
    end

    def update
      if @address.update(address_params)
        redirect_to account_addresses_path, notice: t(".success")
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @address.destroy
      redirect_to account_addresses_path, notice: t(".success")
    end

    private

    def set_address
      @address = current_user.addresses.find(params[:id])
    end

    def address_params
      params.expect(address: [ :label, :first_name, :last_name, :company, :street_line1,
                               :street_line2, :city, :province, :postal_code, :country_id,
                               :phone, :default_shipping ])
    end
  end
end
