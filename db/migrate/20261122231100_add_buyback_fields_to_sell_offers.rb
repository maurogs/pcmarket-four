class AddBuybackFieldsToSellOffers < ActiveRecord::Migration[8.1]
  def change
    add_reference :sell_offers, :buyback_price, foreign_key: true

    add_column :sell_offers, :offer_expires_at, :datetime
    add_column :sell_offers, :accepted_at, :datetime
    add_column :sell_offers, :declined_at, :datetime
    add_column :sell_offers, :received_at, :datetime
    add_column :sell_offers, :paid_at, :datetime
    add_column :sell_offers, :rejected_at, :datetime
    add_column :sell_offers, :original_box, :boolean, null: false, default: false
    add_column :sell_offers, :accessories, :string
    add_column :sell_offers, :payout_iban, :text
    add_column :sell_offers, :payout_account_name, :string
    add_column :sell_offers, :admin_notes, :text

    add_index :sell_offers, :offer_expires_at
  end
end
