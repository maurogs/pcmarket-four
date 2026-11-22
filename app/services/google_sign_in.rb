class GoogleSignIn
  class Error < StandardError; end

  def initialize(id_token)
    @id_token = id_token
  end

  def call
    data = GoogleTokenVerifier.new(@id_token).payload
    email = data["email"].to_s.downcase
    raise Error, "email_missing" if email.blank?

    user = User.find_by(provider: "google_oauth2", uid: data["sub"].to_s) ||
           User.find_by(email: email)

    if user
      raise Error, "suspended" unless user.active_account?

      user.update!(provider: "google_oauth2", uid: data["sub"].to_s)
      user.confirm unless user.confirmed?
    else
      user = User.create!(
        email: email,
        provider: "google_oauth2",
        uid: data["sub"].to_s,
        first_name: data["given_name"],
        last_name: data["family_name"],
        password: Devise.friendly_token[0, 20],
        confirmed_at: Time.current,
        terms_accepted_at: Time.current,
        country_code: "ES"
      )
    end

    user
  end
end
