class Follow < ApplicationRecord
  belongs_to :follower, class_name: "User", inverse_of: :follows
  belongs_to :store, counter_cache: :followers_count, inverse_of: :follows

  validates :store_id, uniqueness: { scope: :follower_id }
end
