# POST / DELETE /s/:store_slug/follow — follow or unfollow a store. Turbo
# Stream replaces the follow button and the followers count; plain HTML
# requests fall back to a redirect back. Following your own store fails the
# Follow validation and simply re-renders the button unchanged.
class Stores::FollowsController < ApplicationController
  include Browseable

  before_action :authenticate_user!
  before_action :set_store

  def create
    follow = current_user.follows.new(store: @store)
    follow.save

    respond_to do |format|
      format.turbo_stream { render_follow_state }
      format.html do
        if follow.persisted?
          redirect_back fallback_location: store_path(@store), status: :see_other,
                        notice: t(".success", store: @store.display_name)
        else
          redirect_back fallback_location: store_path(@store), status: :see_other,
                        alert: follow.errors[:store].to_sentence
        end
      end
    end
  end

  def destroy
    current_user.follows.find_by(store: @store)&.destroy

    respond_to do |format|
      format.turbo_stream { render_follow_state }
      format.html do
        redirect_back fallback_location: store_path(@store), status: :see_other,
                      notice: t(".success", store: @store.display_name)
      end
    end
  end

  private

  def set_store
    @store = Store.find_by_param(params[:store_slug])
    render_not_found unless @store
  end

  # The counter-cache update happens in SQL, so reload before re-rendering.
  def render_follow_state
    @store.reload
    render :follow_state, formats: [ :turbo_stream ]
  end
end
