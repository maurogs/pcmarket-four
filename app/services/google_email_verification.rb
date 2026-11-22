# Shared Google email verification rule for web OmniAuth and the JSON API.
module GoogleEmailVerification
  module_function

  def verified?(value)
    value == true || value.to_s.downcase == "true"
  end

  def verified_auth?(auth)
    raw = auth&.extra&.raw_info
    return false if raw.blank?

    value = if raw.respond_to?(:email_verified)
      raw.email_verified
    else
      raw[:email_verified] || raw["email_verified"]
    end

    verified?(value)
  end
end
