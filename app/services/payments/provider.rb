module Payments
  class SignatureError < StandardError; end

  # Payment providers share two entry points: start (returns a redirect URL or
  # nil when the order is confirmed in place) and handle_webhook.
  class Provider
    def start(_orders, _return_urls)
      raise NotImplementedError
    end

    def handle_webhook(_request)
      raise NotImplementedError
    end
  end
end
