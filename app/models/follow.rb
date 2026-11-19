# A user following a store. Keeps Store#followers_count in sync via the
# counter cache; following your own store is not allowed.
class Follow < ApplicationRecord
  belongs_to :follower, class_name: "User"
  belongs_to :store, counter_cache: :followers_count

  validates :store_id, uniqueness: { scope: :follower_id }
  validate :not_own_store

  private

  def not_own_store
    errors.add(:store, :following_own_store) if store && follower_id == store.user_id
  end
end
