module Demo
  # Removes every record created by Demo::Seed, including Active Storage blobs
  # uploaded for demo listings, store branding and avatars.
  class Reset
    STAFF_EMAILS = %w[moderator@pcmarket.test].freeze

    def self.call
      new.call
    end

    def call
      user_ids = User.where("email LIKE ?", Seed::DEMO_EMAIL_PATTERN)
                     .or(User.where(email: STAFF_EMAILS)).pluck(:id)
      return warn_no_demo_data if user_ids.empty?

      ActiveRecord::Base.transaction do
        remove_orders(user_ids)
        remove_messages(user_ids)
        remove_social(user_ids)
        remove_listings_and_stores(user_ids)
        remove_staff(user_ids)
      end

      purge_demo_blobs
      puts "Demo data removed. Run bin/rails db:seed or bin/rails demo:seed to recreate it."
      true
    end

    private

    def warn_no_demo_data
      puts "No demo data found."
      false
    end

    def remove_orders(user_ids)
      order_ids = Order.where(buyer_id: user_ids).or(Order.where(seller_id: user_ids)).pluck(:id)
      return if order_ids.empty?

      Review.where(order_id: order_ids).delete_all
      OrderNote.where(order_id: order_ids).delete_all
      OrderEvent.where(order_id: order_ids).delete_all
      OrderItem.where(order_id: order_ids).delete_all
      Order.where(id: order_ids).delete_all
    end

    def remove_messages(user_ids)
      conversation_ids = Conversation.where(buyer_id: user_ids)
                                     .or(Conversation.where(seller_id: user_ids))
                                     .pluck(:id)
      return if conversation_ids.empty?

      Message.where(conversation_id: conversation_ids).delete_all
      Conversation.where(id: conversation_ids).delete_all
    end

    def remove_social(user_ids)
      listing_ids = Listing.where(user_id: user_ids).pluck(:id)
      store_ids = Store.where(user_id: user_ids).pluck(:id)

      Favorite.where(user_id: user_ids).or(Favorite.where(listing_id: listing_ids)).delete_all
      Follow.where(follower_id: user_ids).or(Follow.where(store_id: store_ids)).delete_all
      SavedSearch.where(user_id: user_ids).delete_all
      CartItem.where(user_id: user_ids).or(CartItem.where(listing_id: listing_ids)).delete_all
      Notification.where(user_id: user_ids).delete_all
      Report.where(reporter_id: user_ids)
            .or(Report.where(resolved_by_id: user_ids))
            .or(Report.where(reportable_type: "Listing", reportable_id: listing_ids))
            .delete_all
      Block.where(blocker_id: user_ids).or(Block.where(blocked_id: user_ids)).delete_all
      Address.where(user_id: user_ids).delete_all
      ApiToken.where(user_id: user_ids).delete_all
      Device.where(user_id: user_ids).delete_all
      FeatureRequest.where(user_id: user_ids)
                    .or(FeatureRequest.where(listing_id: listing_ids)).delete_all
      SellOffer.where(user_id: user_ids).delete_all
      Review.where(reviewer_id: user_ids).or(Review.where(store_id: store_ids)).delete_all
      AdminAuditLog.where(admin_id: user_ids).delete_all
      NewsletterSubscriber.where("email LIKE ?", Seed::DEMO_EMAIL_PATTERN).delete_all
    end

    def remove_listings_and_stores(user_ids)
      listing_ids = Listing.where(user_id: user_ids).pluck(:id)
      store_ids = Store.where(user_id: user_ids).pluck(:id)
      purge_attachments("Listing", listing_ids)
      purge_attachments("Store", store_ids)
      purge_attachments("User", user_ids)

      FriendlyId::Slug.where(sluggable_type: "Listing", sluggable_id: listing_ids).delete_all
      FriendlyId::Slug.where(sluggable_type: "Store", sluggable_id: store_ids).delete_all
      Listing.where(id: listing_ids).delete_all
      Store.where(id: store_ids).delete_all
    end

    def remove_staff(user_ids)
      User.where(id: user_ids).delete_all
    end

    def purge_attachments(record_type, record_ids)
      return if record_ids.empty?

      attachments = ActiveStorage::Attachment.where(record_type: record_type, record_id: record_ids)
      @blob_ids = Array(@blob_ids) | attachments.pluck(:blob_id)
      attachments.delete_all
    end

    def purge_demo_blobs
      blobs = ActiveStorage::Blob.where(id: Array(@blob_ids))
      blobs.find_each(&:purge)

      ActiveStorage::Blob.where("metadata LIKE ?", "%\"demo\":true%").find_each(&:purge)
    end
  end
end
