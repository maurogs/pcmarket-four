class CreateOrderNumberSequence < ActiveRecord::Migration[8.1]
  def up
    execute "CREATE SEQUENCE IF NOT EXISTS order_number_seq START WITH 1 INCREMENT BY 1"

    # Keep the sequence ahead of any numbers created before it existed.
    highest = select_value(
      "SELECT MAX(split_part(number, '-', 3)::bigint) FROM orders WHERE number ~ '^PCM-[0-9]{4}-[0-9]+$'"
    ).to_i
    if highest.positive?
      execute "SELECT setval('order_number_seq', #{highest}, true)"
    else
      execute "SELECT setval('order_number_seq', 1, false)"
    end
  end

  def down
    execute "DROP SEQUENCE IF EXISTS order_number_seq"
  end
end
