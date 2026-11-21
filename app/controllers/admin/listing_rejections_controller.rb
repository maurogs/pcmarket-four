module Admin
  class ListingRejectionsController < BaseController
    PRESET_REASONS = %w[prohibited misleading poor_photos wrong_category suspicious_price
                        duplicate other].freeze

    def create
      listing = Listing.friendly.find(params[:listing_id])
      authorize_admin!(listing, :reject?)

      reason = rejection_reason
      if reason.present? && Admin::ListingModeration.reject(listing, current_user, reason)
        audit!("listing.rejected", listing, changeset: { "rejection_reason" => reason })
        redirect_back_or_to admin_moderation_queue_path,
                            notice: t("admin.moderation.rejected", title: listing.title)
      else
        redirect_back_or_to admin_moderation_queue_path,
                            alert: t("admin.moderation.reason_required")
      end
    end

    private

    def rejection_reason
      key = params[:reason].to_s
      return params[:other_reason].to_s.strip if key == "other"
      return I18n.t("admin.moderation.reasons.#{key}") if PRESET_REASONS.include?(key)

      params[:reason_detail].to_s.strip
    end
  end
end
