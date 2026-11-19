class CreateListingSellerTags < ActiveRecord::Migration[8.1]
  def change
    create_table :listing_seller_tags do |t|
      t.references :listing, null: false, foreign_key: true
      t.references :seller_tag, null: false, foreign_key: true

      t.timestamps
    end

    add_index :listing_seller_tags, [ :listing_id, :seller_tag_id ], unique: true
  end
end
