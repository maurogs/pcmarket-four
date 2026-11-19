class CreateReviews < ActiveRecord::Migration[8.1]
  def change
    create_table :reviews do |t|
      # Both FK columns are leading columns of the composite indexes below.
      t.references :store, null: false, index: false, foreign_key: true
      t.references :author, null: false, index: false, foreign_key: { to_table: :users }
      t.references :listing, foreign_key: { on_delete: :nullify }
      # Phase 5 creates the orders table; the FK comes with it.
      t.bigint :order_id
      # limit: 2 → Postgres smallint
      t.integer :rating, limit: 2, null: false
      t.string :title
      t.text :body
      t.text :seller_reply
      t.datetime :seller_replied_at
      # published | hidden (moderation)
      t.string :status, null: false, default: "published"
      t.boolean :verified_purchase, null: false, default: false

      t.timestamps
    end

    # One review per order per author; reviews without an order are unlimited.
    add_index :reviews, [ :author_id, :order_id ], unique: true, where: "(order_id IS NOT NULL)"
    add_index :reviews, [ :store_id, :status, :created_at ], order: { created_at: :desc }
    add_check_constraint :reviews, "rating >= 1 AND rating <= 5", name: :chk_reviews_rating_range
  end
end
