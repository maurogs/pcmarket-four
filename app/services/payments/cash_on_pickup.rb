module Payments
  class CashOnPickup < Provider
    def start(_orders, _return_urls)
      nil
    end

    def handle_webhook(_request)
      true
    end
  end
end
