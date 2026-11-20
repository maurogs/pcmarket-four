class CreateCarts < ActiveRecord::Migration[8.1]
  def change
    create_table :carts do |t|
      # Signed-in users have exactly one cart; guest carts keep user_id NULL
      # and are addressed by their token (signed permanent cookie).
      t.references :user, foreign_key: true, index: false
      t.string :token, null: false

      t.timestamps
    end

    # One cart per user; NULLs (guest carts) are excluded from the unique
    # index, which also serves as the user_id FK index.
    add_index :carts, :user_id, unique: true, where: "(user_id IS NOT NULL)"
    add_index :carts, :token, unique: true
  end
end
