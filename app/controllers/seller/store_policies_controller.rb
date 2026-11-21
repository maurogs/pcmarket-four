module Seller
  class StorePoliciesController < BaseController
    def edit
      @store = seller_store
    end

    def update
      @store = seller_store

      if @store.update(policy_params)
        redirect_to edit_seller_store_policy_path,
                    notice: t("seller.policies.saved")
      else
        render :edit, status: :unprocessable_entity
      end
    end

    private

    def policy_params
      params.require(:store).permit(:return_policy, :shipping_policy, :allow_offers_default)
    end
  end
end
