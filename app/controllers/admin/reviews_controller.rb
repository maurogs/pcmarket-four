module Admin
  class ReviewsController < BaseController
    before_action :set_review, only: %i[show update destroy]

    def index
      authorize_admin!(Review, :index?)

      @query = Admin::ReviewQuery.new(filter_params)
      @reviews = @query.call
      @pagy, @reviews = pagy(@reviews, limit: pagination_limit)
    end

    def show
      authorize_admin!(@review, :show?)
      @audit_logs = AdminAuditLog.where(auditable: @review).includes(:admin).recent.limit(10)
    end

    def update
      authorize_admin!(@review, :visibility?)

      attributes = {}
      attributes[:published] = params.dig(:review, :published) if params.dig(:review, :published).present?
      if params.key?(:review) && params[:review].key?(:seller_reply_visible)
        attributes[:seller_reply_visible] = ActiveModel::Type::Boolean.new.cast(params.dig(:review, :seller_reply_visible))
      end

      if @review.update(attributes)
        audit!("review.updated", @review)
        redirect_to admin_review_path(@review), notice: t("admin.reviews.updated")
      else
        redirect_to admin_review_path(@review), alert: t("admin.reviews.cannot_update")
      end
    end

    def destroy
      authorize_admin!(@review, :destroy?)

      review = @review
      review.destroy!
      audit!("review.deleted", review, changeset: { "body" => review.body })
      redirect_to admin_reviews_path, notice: t("admin.reviews.deleted")
    end

    private

    def set_review
      @review = Review.includes(:reviewer, :store, order: %i[buyer seller]).find(params[:id])
    end

    def filter_params
      params.permit(:rating, :published, :store, :has_reply, :created_from, :created_to,
                    :sort, :direction)
    end
  end
end
