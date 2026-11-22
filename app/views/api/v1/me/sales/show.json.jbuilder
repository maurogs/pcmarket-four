json.data do
  json.partial! "api/v1/orders/order", order: @order
end
json.meta({})
