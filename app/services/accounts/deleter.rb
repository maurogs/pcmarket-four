module Accounts
  # GDPR right to erasure: anonymizes the user in place (the row survives so
  # published reviews keep their author FK and stay displayed as
  # "Deleted user"), archives their listings, parks the store on vacation —
  # which unpublishes it, since every public listing scope excludes vacation
  # stores — and erases the shipping addresses. deleted_at then makes
  # User#active_for_authentication? false for good.
  class Deleter
    def self.call(user)
      new(user).call
    end

    def initialize(user)
      @user = user
    end

    def call
      user.transaction do
        archive_listings
        park_store
        user.addresses.destroy_all
        anonymize!
        user.update!(deleted_at: Time.current)
      end
      user
    end

    private

    attr_reader :user

    # AASM archive! from every non-archived state; the after_save counter jobs
    # keep category/store counters honest.
    def archive_listings
      store = user.store
      return if store.blank?

      store.listings.where.not(status: "archived").find_each do |listing|
        listing.archive!
      end
    end

    def park_store
      store = user.store
      return if store.blank?

      store.update!(vacation_mode: true)
    end

    def anonymize!
      # skip_reconfirmation! keeps Devise from treating the email swap as a
      # pending change that needs confirming (there is nobody to confirm it).
      user.skip_reconfirmation!
      user.update!(
        email: "deleted-#{user.id}@deleted.invalid",
        # "deleted-user-<id>" would read nicer, but the username format
        # validation only allows [a-z0-9_], so the separator is an underscore.
        username: "deleted_user_#{user.id}",
        first_name: nil,
        last_name: nil,
        phone: nil,
        unconfirmed_email: nil,
        notification_preferences: {},
        marketing_opt_in: false
      )
      user.avatar.purge
      user.data_export.purge
    end
  end
end
