class AddCheckoutFieldsToOrders < ActiveRecord::Migration[8.1]
  def up
    change_column_null :orders, :buyer_id, true

    add_column :orders, :payment_method, :string
    add_column :orders, :locale, :string, null: false, default: "es"
    add_column :orders, :checkout_token, :string
    add_column :orders, :guest_access_token, :string
    add_column :orders, :terms_accepted_at, :datetime
    add_column :orders, :stock_restored_at, :datetime

    add_index :orders, [ :checkout_token, :seller_id ], unique: true,
              where: "checkout_token IS NOT NULL",
              name: "index_orders_on_checkout_token_and_seller"
    add_index :orders, :guest_access_token, unique: true,
              where: "guest_access_token IS NOT NULL"
  end

  def down
    remove_index :orders, name: "index_orders_on_guest_access_token"
    remove_index :orders, name: "index_orders_on_checkout_token_and_seller"

    remove_column :orders, :stock_restored_at
    remove_column :orders, :terms_accepted_at
    remove_column :orders, :guest_access_token
    remove_column :orders, :checkout_token
    remove_column :orders, :locale
    remove_column :orders, :payment_method

    change_column_null :orders, :buyer_id, false
  end
end
