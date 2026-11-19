# Seller store settings: /:locale/seller/store. new/create is the "open your
# store" flow, available only while the user has none; afterwards the same
# form edits the existing store. The singular route means every action works
# strictly on current_user.store — other sellers' stores are unreachable.
module Seller
  class StoresController < ApplicationController
    before_action :authenticate_user!
    before_action :set_store
    before_action :redirect_to_own_store, only: %i[new create]
    before_action :redirect_to_open_store, only: %i[edit update]

    def new
      @store = current_user.build_store
    end

    def create
      @store = current_user.build_store
      @store.assign_settings(store_params)
      if @store.save
        redirect_to edit_seller_store_path, notice: t(".success")
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit; end

    def update
      if @store.assign_settings(store_params).save
        redirect_to edit_seller_store_path, notice: t(".success")
      else
        render :edit, status: :unprocessable_entity
      end
    end

    private

    def set_store
      @store = current_user.store
    end

    # One store per user: the opening flow bounces back to the settings page.
    def redirect_to_own_store
      redirect_to edit_seller_store_path if @store
    end

    # No store yet — the settings page sends the seller to the opening flow.
    def redirect_to_open_store
      redirect_to new_seller_store_path unless @store
    end

    def store_params
      params.expect(store: %i[name bio kind business_name tax_id logo banner
                              remove_logo remove_banner vacation_mode vacation_message
                              allow_offers_default city province postal_code])
    end
  end
end
