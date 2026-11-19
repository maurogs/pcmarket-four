class CreateGames < ActiveRecord::Migration[8.1]
  def change
    create_table :games do |t|
      t.string :slug, null: false
      t.string :name, null: false
      t.integer :position, default: 0
      t.boolean :active, null: false, default: true
      # Benchmark targets per resolution/fps: { "1080p": { "60": 20, "144": 45 } }.
      t.jsonb :demand, null: false, default: {}
      # Share of the listing performance score contributed by the CPU.
      t.decimal :cpu_weight, precision: 4, scale: 2, null: false, default: 0.3

      t.timestamps
    end

    add_index :games, :slug, unique: true
  end
end
