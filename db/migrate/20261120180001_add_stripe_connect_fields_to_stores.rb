# Stripe Connect state for seller payouts (Phase 4 step 4a). The account id
# is unique across stores (one Stripe account per store); the boolean flags
# are a cached copy of the Stripe account, refreshed by
# Payments::ConnectOnboarding.sync! (see stripe_synced_at).
class AddStripeConnectFieldsToStores < ActiveRecord::Migration[8.1]
  def change
    add_column :stores, :stripe_account_id, :string
    add_column :stores, :stripe_charges_enabled, :boolean, default: false, null: false
    add_column :stores, :stripe_payouts_enabled, :boolean, default: false, null: false
    add_column :stores, :stripe_details_submitted, :boolean, default: false, null: false
    add_column :stores, :stripe_synced_at, :datetime

    add_index :stores, :stripe_account_id, unique: true, where: "stripe_account_id IS NOT NULL"
  end
end
