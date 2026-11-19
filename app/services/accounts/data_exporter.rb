module Accounts
  # GDPR data portability: builds the user's export JSON (profile, addresses,
  # notification preferences, store + its listings, follows, reviews written),
  # attaches it as User#data_export and stamps data_export_generated_at.
  # Called from Account::DataExportJob; the 24h request throttle lives in
  # User#data_export_throttled? and is checked by the controller before
  # enqueueing.
  class DataExporter
    def self.call(user)
      new(user).call
    end

    def initialize(user)
      @user = user
    end

    # Returns the generated JSON string (handy for tests and debugging).
    def call
      json = JSON.pretty_generate(payload)
      user.data_export.attach(
        io: StringIO.new(json),
        filename: "pcmarket-export-#{user.id}-#{Time.current.utc.strftime("%Y%m%d%H%M%S")}.json",
        content_type: "application/json"
      )
      user.update!(data_export_generated_at: Time.current)
      json
    end

    private

    attr_reader :user

    def payload
      {
        generated_at: Time.current.utc.iso8601,
        profile: profile,
        addresses: addresses,
        notification_preferences: notification_preferences,
        store: store_payload,
        follows: follows,
        reviews: reviews
      }
    end

    def profile
      {
        email: user.email,
        username: user.username,
        first_name: user.first_name,
        last_name: user.last_name,
        phone: user.phone,
        locale: user.locale,
        country: user.country&.code,
        role: user.role,
        created_at: utc(user.created_at),
        sign_in_count: user.sign_in_count,
        current_sign_in_at: utc(user.current_sign_in_at),
        last_sign_in_at: utc(user.last_sign_in_at)
      }
    end

    def addresses
      user.addresses.defaults_first.map do |address|
        {
          label: address.label,
          first_name: address.first_name,
          last_name: address.last_name,
          company: address.company,
          street_line1: address.street_line1,
          street_line2: address.street_line2,
          city: address.city,
          province: address.province,
          postal_code: address.postal_code,
          country: address.country.code,
          phone: address.phone,
          default_shipping: address.default_shipping
        }
      end
    end

    def notification_preferences
      {
        preferences: user.notification_preferences,
        marketing_opt_in: user.marketing_opt_in,
        marketing_opt_in_at: utc(user.marketing_opt_in_at)
      }
    end

    def store_payload
      store = user.store
      return if store.blank?

      {
        name: store.name,
        slug: store.slug,
        kind: store.kind,
        bio: store.bio,
        business_name: store.business_name,
        tax_id: store.tax_id,
        city: store.city,
        province: store.province,
        postal_code: store.postal_code,
        verified: store.verified,
        vacation_mode: store.vacation_mode,
        rating_avg: store.rating_avg,
        ratings_count: store.ratings_count,
        created_at: utc(store.created_at),
        listings: listings(store)
      }
    end

    def listings(store)
      store.listings.order(:id).map do |listing|
        {
          id: listing.id,
          slug: listing.slug,
          title: listing.title,
          description: listing.description,
          price_cents: listing.price_cents,
          currency: listing.currency,
          condition: listing.condition,
          status: listing.status,
          category: listing.category.slug,
          created_at: utc(listing.created_at),
          published_at: utc(listing.published_at)
        }
      end
    end

    def follows
      user.follows.includes(:store).order(:id).map do |follow|
        { store: follow.store.name, slug: follow.store.slug, followed_at: utc(follow.created_at) }
      end
    end

    def reviews
      user.reviews_written.includes(:store).order(:id).map do |review|
        {
          store: review.store.name,
          rating: review.rating,
          title: review.title,
          body: review.body,
          status: review.status,
          created_at: utc(review.created_at)
        }
      end
    end

    def utc(time)
      time&.utc&.iso8601
    end
  end
end
