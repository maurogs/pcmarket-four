# frozen_string_literal: true

class Rack::Attack
  # Throttle abusive clients without affecting normal browsing.
  throttle("req/ip", limit: 300, period: 5.minutes) do |req|
    req.ip unless req.path.start_with?("/assets", "/up")
  end

  throttle("logins/ip", limit: 10, period: 20.minutes) do |req|
    req.ip if req.path.end_with?("/users/sign_in") && req.post?
  end

  throttle("api/ip", limit: 120, period: 1.minute) do |req|
    req.ip if req.path.start_with?("/api")
  end

  self.throttled_responder = lambda do |_request|
    [ 429, { "Content-Type" => "text/plain" }, [ I18n.t("errors.rate_limited") ] ]
  end
end
