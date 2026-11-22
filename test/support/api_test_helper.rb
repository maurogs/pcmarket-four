module ApiTestHelper
  BUYER_TOKEN = "buyer-api-token-123456".freeze

  def api_headers(token = BUYER_TOKEN, extra = {})
    headers = { "Accept" => "application/json" }
    headers["Authorization"] = "Bearer #{token}" if token.present?
    headers.merge(extra)
  end

  def json_body
    JSON.parse(response.body)
  end

  def api_get(path, token: BUYER_TOKEN, headers: {})
    get path, headers: api_headers(token, headers)
  end

  def api_post(path, params: {}, token: BUYER_TOKEN, headers: {})
    post path, params: params, headers: api_headers(token, headers), as: :json
  end

  def api_patch(path, params: {}, token: BUYER_TOKEN, headers: {})
    patch path, params: params, headers: api_headers(token, headers), as: :json
  end

  def api_delete(path, token: BUYER_TOKEN, headers: {})
    delete path, headers: api_headers(token, headers)
  end

  def assert_success_envelope
    assert_includes %w[200 201 202], response.status.to_s
    assert json_body.key?("data")
    assert json_body.key?("meta")
  end

  def assert_error_envelope(status, code = nil)
    assert_equal status, response.status
    assert json_body.key?("error")
    assert_equal code, json_body.dig("error", "code") if code
    assert json_body.dig("error", "message").present?
  end

  def issue_token_for(user, expires_at: nil)
    ApiToken.issue!(user: user, expires_at: expires_at).plain_token
  end
end
