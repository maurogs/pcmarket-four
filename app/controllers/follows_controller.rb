class FollowsController < ApplicationController
  before_action :authenticate_user!

  def create
    store = Store.friendly.find(params[:store_id])
    follow = current_user.follows.find_or_create_by!(store: store)
    respond_to_follow(store, follow, following: true)
  end

  def destroy
    follow = current_user.follows.find(params[:id])
    store = follow.store
    follow.destroy!
    respond_to_follow(store, nil, following: false)
  end

  private

  def respond_to_follow(store, follow, following:)
    store.reload

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.replace(
            "store-follow-#{store.id}",
            partial: "stores/follow_button",
            locals: { store: store, follow: follow }
          ),
          turbo_stream.replace(
            "store-followers-#{store.id}",
            partial: "stores/followers_count",
            locals: { store: store }
          )
        ]
      end
      format.html do
        redirect_back fallback_location: store_path(store),
                    notice: t(following ? "stores.followed" : "stores.unfollowed")
      end
    end
  end
end
