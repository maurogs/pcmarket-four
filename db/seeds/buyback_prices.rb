gpu_prices = {
  "RTX 5090" => 190_000,
  "RTX 5080" => 130_000,
  "RTX 5070 Ti" => 98_000,
  "RTX 5070" => 72_000,
  "RTX 5060 Ti" => 48_000,
  "RTX 4090" => 150_000,
  "RTX 4080" => 95_000,
  "RTX 4070 Ti" => 72_000,
  "RTX 4070" => 52_000,
  "RTX 4060 Ti" => 34_000,
  "RTX 3090" => 72_000,
  "RTX 3080" => 46_000,
  "RX 7900 XTX" => 82_000,
  "RX 7800 XT" => 44_000,
  "RX 6700 XT" => 24_000
}

cpu_prices = {
  "Ryzen 9 9950X" => 52_000,
  "Ryzen 9 7950X" => 42_000,
  "Ryzen 7 9800X3D" => 40_000,
  "Ryzen 7 7800X3D" => 30_000,
  "Ryzen 7 5800X3D" => 20_000,
  "Ryzen 5 7600X" => 14_000,
  "Core i9-14900K" => 38_000,
  "Core i9-13900K" => 30_000,
  "Core i7-13700K" => 22_000,
  "Core i5-13600K" => 15_000
}

[ [ "gpu", gpu_prices ], [ "cpu", cpu_prices ] ].each do |kind, prices|
  prices.each_with_index do |(item_model, base_price_cents), index|
    price = BuybackPrice.find_or_initialize_by(item_kind: kind, item_model: item_model)
    price.assign_attributes(
      base_price_cents: base_price_cents,
      condition_multipliers: BuybackPrice::CONDITION_MULTIPLIERS,
      active: true,
      position: index + 1
    )
    price.save!
  end
end
