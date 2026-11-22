# frozen_string_literal: true

class Rack::Attack
  Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new

  # Throttle abusive clients without affecting normal browsing.
  throttle("req/ip", limit: 300, period: 5.minutes) do |req|
    req.ip unless req.path.start_with?("/assets", "/up", "/api")
  end

  throttle("logins/ip", limit: 10, period: 20.minutes) do |req|
    req.ip if req.path.end_with?("/users/sign_in") && req.post?
  end

  # Versioned API: authenticated requests are limited per token, anonymous
  # requests per IP, and credential endpoints have stricter limits.
  throttle("api/token", limit: 300, period: 5.minutes) do |req|
    next unless req.path.start_with?("/api/v1")

    token = req.get_header("HTTP_AUTHORIZATION").to_s[/\ABearer\s+(.+)\z/i, 1]
    ApiToken.digest(token) if token.present?
  end

  throttle("api/ip", limit: 60, period: 5.minutes) do |req|
    next unless req.path.start_with?("/api/v1")

    token = req.get_header("HTTP_AUTHORIZATION").to_s[/\ABearer\s+(.+)\z/i, 1]
    req.ip if token.blank?
  end

  throttle("api/login/ip", limit: 10, period: 1.minute) do |req|
    req.ip if req.post? && req.path == "/api/v1/auth/sessions"
  end

  throttle("api/login/email", limit: 10, period: 1.minute) do |req|
    next unless req.post? && req.path == "/api/v1/auth/sessions"

    email = req.params["email"].to_s.strip.downcase
    if email.blank? && req.media_type.to_s.include?("json")
      body = req.body.read
      req.body.rewind
      parsed = JSON.parse(body) rescue {}
      email = parsed["email"].to_s.strip.downcase
    end
    email.presence
  end

  self.throttled_responder = lambda do |request|
    if request.path.start_with?("/api")
      body = {
        error: {
          code: "rate_limited",
          message: I18n.t("api.errors.rate_limited"),
          details: {}
        }
      }.to_json

      [ 429, { "Content-Type" => "application/json" }, [ body ] ]
    else
      [ 429, { "Content-Type" => "text/plain" }, [ I18n.t("errors.rate_limited") ] ]
    end
  end
end
