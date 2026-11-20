class AddImageOrderToListings < ActiveRecord::Migration[8.1]
  def change
    # Seller-chosen gallery order: JSON array of blob signed ids / attachment
    # ids. Images missing from the array fall back to attachment order.
    add_column :listings, :image_order, :jsonb, null: false, default: []
  end
end
