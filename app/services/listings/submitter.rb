# Submits a listing for review on the seller's behalf: draft/rejected →
# pending_review, or straight to published when the listing_auto_approve
# setting is on. Returns a Result with success? and human-readable errors —
# the listing's validation messages (missing photos, required specs, …) or a
# translated notice when the current state forbids the transition — so both
# the submissions controller and the sell form's "Save & submit" report
# failures the same way. invalid_transition? tells the caller which of the
# two happened (they redirect differently: edit page vs. index).
module Listings
  class Submitter
    Result = Struct.new(:listing, :errors, :invalid_transition) do
      def success?
        errors.empty?
      end

      def invalid_transition?
        !!invalid_transition
      end
    end

    def self.call(listing)
      new(listing).call
    end

    def initialize(listing)
      @listing = listing
    end

    def call
      unless listing.may_submit?
        return Result.new(listing, [ I18n.t("seller.listings.invalid_transition") ], true)
      end

      # AASM's bang event persists with save!, which raises RecordInvalid
      # when the submit validations (photos, required specs) fail; the
      # listing's errors are already populated by the failed save.
      begin
        listing.submit!
      rescue ActiveRecord::RecordInvalid
        return Result.new(listing, listing.errors.full_messages)
      end

      listing.approve! if AppSettings.enabled?("listing_auto_approve")
      Result.new(listing, [])
    end

    private

    attr_reader :listing
  end
end
