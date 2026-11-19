# Join between listings and product labels (marketing badges).
class ListingLabel < ApplicationRecord
  belongs_to :listing
  belongs_to :product_label

  validates :product_label_id, uniqueness: { scope: :listing_id }
end
