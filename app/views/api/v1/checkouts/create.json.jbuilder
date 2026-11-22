json.data do
  json.orders @orders do |order|
    json.partial! "api/v1/orders/order", order: order
  end
  json.payment_method @payment_method
  json.redirect_url @redirect_url
  json.payment_instructions @payment_instructions
  json.total api_money(@orders.sum(&:total_cents))
end
json.meta({})
