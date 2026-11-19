# Singular nested resource: PATCH /:locale/account/addresses/:address_id/default
# makes the scoped address the user's default shipping address.
module Account
  class AddressDefaultsController < ApplicationController
    before_action :authenticate_user!

    def update
      address = current_user.addresses.find(params[:address_id])
      address.make_default!
      redirect_back_or_to account_addresses_path, notice: t(".success")
    end
  end
end
