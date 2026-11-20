# Idempotency ledger for Stripe webhooks (Phase 4 step 4b): one row per
# delivered event id, so a retried delivery never re-applies a transition.
# The unique index is the real guard — the handler rescues the clash.
class CreateStripeEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :stripe_events do |t|
      t.string :stripe_id, null: false
      t.string :event_type, null: false
      # Stamped once the event has been handled; NULL would mean "crashed
      # mid-processing" (the handler records only after a successful run).
      t.datetime :processed_at
      t.jsonb :payload, null: false, default: {}

      t.timestamps
    end

    add_index :stripe_events, :stripe_id, unique: true
  end
end
