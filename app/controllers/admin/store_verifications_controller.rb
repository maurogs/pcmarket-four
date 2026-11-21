module Admin
  class StoreVerificationsController < BaseController
    def create
      store = Store.find(params[:store_id])
      authorize_admin!(store, :verify?)

      store.update!(verified: true)
      audit!("store.verified", store, changeset: { "verified" => [ false, true ] })
      redirect_back_or_to admin_store_path(store), notice: t("admin.stores.verified")
    end

    def destroy
      store = Store.find(params[:store_id])
      authorize_admin!(store, :unverify?)

      store.update!(verified: false)
      audit!("store.unverified", store, changeset: { "verified" => [ true, false ] })
      redirect_back_or_to admin_store_path(store), notice: t("admin.stores.unverified")
    end
  end
end
