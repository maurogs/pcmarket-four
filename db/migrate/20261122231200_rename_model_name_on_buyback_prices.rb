class RenameModelNameOnBuybackPrices < ActiveRecord::Migration[8.1]
  def change
    rename_column :buyback_prices, :model_name, :item_model
  end
end
