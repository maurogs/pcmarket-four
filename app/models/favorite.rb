class Favorite < ApplicationRecord
  belongs_to :user, inverse_of: :favorites
  belongs_to :listing, counter_cache: :favorites_count, inverse_of: :favorites

  validates :listing_id, uniqueness: { scope: :user_id }
end
