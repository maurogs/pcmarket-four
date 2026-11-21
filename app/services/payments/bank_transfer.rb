module Payments
  class BankTransfer < Provider
    def start(_orders, _return_urls)
      nil
    end

    def handle_webhook(_request)
      true
    end
  end
end
