module Seller
  class VacationsController < BaseController
    def edit
      @store = seller_store
    end

    def update
      @store = seller_store

      if @store.update(vacation_params)
        redirect_to edit_seller_vacation_path,
                    notice: t("seller.vacation.saved")
      else
        render :edit, status: :unprocessable_entity
      end
    end

    private

    def vacation_params
      params.require(:store).permit(:vacation_mode, :vacation_message)
    end
  end
end
