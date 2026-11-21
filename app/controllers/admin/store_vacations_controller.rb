module Admin
  class StoreVacationsController < BaseController
    def create
      store = Store.find(params[:store_id])
      authorize_admin!(store, :vacation?)

      store.update!(vacation_mode: true)
      audit!("store.vacation_started", store, changeset: { "vacation_mode" => [ false, true ] })
      redirect_back_or_to admin_store_path(store), notice: t("admin.stores.vacation_started")
    end

    def destroy
      store = Store.find(params[:store_id])
      authorize_admin!(store, :end_vacation?)

      store.update!(vacation_mode: false)
      audit!("store.vacation_ended", store, changeset: { "vacation_mode" => [ true, false ] })
      redirect_back_or_to admin_store_path(store), notice: t("admin.stores.vacation_ended")
    end
  end
end
