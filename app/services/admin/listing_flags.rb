module Admin
  # Heuristics shown in the moderation queue. None of them blocks a decision;
  # they only help moderators look at the right things first.
  class ListingFlags
    Result = Struct.new(:listing, :price_median_cents, :suspicious_price, :safety,
                        :duplicate_listings, :seller, keyword_init: true) do
      def suspicious_price?
        suspicious_price
      end

      def safety_reasons
        safety[:reasons]
      end

      def duplicate?
        duplicate_listings.any?
      end
    end

    SellerStats = Struct.new(:account_age_days, :listings_count, :completed_sales,
                             :rating, :previous_rejections, :verified, keyword_init: true)

    def self.call(listing)
      new(listing).call
    end

    def initialize(listing)
      @listing = listing
    end

    def call
      Result.new(
        listing: listing,
        price_median_cents: price_median_cents,
        suspicious_price: suspicious_price?,
        safety: MessageSafetyScanner.call(listing.description),
        duplicate_listings: duplicate_listings,
        seller: seller_stats
      )
    end

    private

    attr_reader :listing

    def price_median_cents
      @price_median_cents ||= Listing.published
                                     .where(category_id: listing.category_id)
                                     .pick(Arel.sql("percentile_cont(0.5) WITHIN GROUP (ORDER BY price_cents)"))
                                     &.to_i
    end

    def suspicious_price?
      median = price_median_cents.to_i
      median.positive? && listing.price_cents.to_i < (median * 0.4)
    end

    def duplicate_listings
      @duplicate_listings ||= begin
        checksums = listing.images.blobs.map(&:checksum).compact.uniq
        if checksums.empty?
          []
        else
          blob_ids = ActiveStorage::Blob.where(checksum: checksums).pluck(:id)
          ActiveStorage::Attachment
            .where(record_type: "Listing", blob_id: blob_ids)
            .where.not(record_id: listing.id)
            .includes(record: %i[user store])
            .filter_map(&:record)
            .reject { |other| other.user_id == listing.user_id }
            .uniq
        end
      end
    end

    def seller_stats
      user = listing.user
      store = user.store
      SellerStats.new(
        account_age_days: [ (Date.current - user.created_at.to_date).to_i, 0 ].max,
        listings_count: user.listings.count,
        completed_sales: Order.where(seller_id: user.id, status: :completed).count,
        rating: store&.rating_avg.to_f,
        previous_rejections: user.listings.where(status: :rejected).count,
        verified: store&.verified? || false
      )
    end
  end
end
