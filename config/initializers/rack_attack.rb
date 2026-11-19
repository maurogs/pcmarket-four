# Basic throttling for the most exposed endpoints. Limits are generous for
# humans, tight enough to blunt credential stuffing and scripted signups.
Rails.application.config.middleware.insert_before 0, Rack::Attack do
  throttle("logins/ip", limit: 10, period: 1.minute) do |req|
    req.ip if req.path.match?(%r{/users/sign_in\z}) && req.post?
  end

  throttle("signups/ip", limit: 6, period: 10.minutes) do |req|
    req.ip if req.path.match?(%r{/users/sign_up\z}) && req.post?
  end

  throttle("password-resets/ip", limit: 6, period: 10.minutes) do |req|
    req.ip if req.path.match?(%r{/users/password\z}) && req.post?
  end

  # API-readiness: throttle anonymous API traffic before it exists publicly.
  throttle("api/ip", limit: 300, period: 1.minute) do |req|
    req.ip if req.path.start_with?("/api/")
  end

  self.throttled_responder = lambda do |req|
    retry_after = (req.retry_after || 60).to_i
    body = { error: I18n.t("errors.throttled", retry_after: retry_after) }.to_json
    [ 429, { "Retry-After" => retry_after.to_s, "Content-Type" => "application/json" }, [ body ] ]
  end
end
