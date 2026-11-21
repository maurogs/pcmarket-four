module Admin
  class NewsletterSubscribersController < BaseController
    def index
      authorize_admin!(NewsletterSubscriber, :index?)

      @status = params[:status].presence
      @query = params[:q].to_s.strip
      scope = NewsletterSubscriber.order(created_at: :desc)
      scope = filter_status(scope)
      if @query.present?
        scope = scope.where("email ILIKE ?", "%#{NewsletterSubscriber.sanitize_sql_like(@query)}%")
      end
      @counts = {
        confirmed: NewsletterSubscriber.confirmed.count,
        unconfirmed: NewsletterSubscriber.pending.count,
        unsubscribed: NewsletterSubscriber.where.not(unsubscribed_at: nil).count
      }
      @pagy, @subscribers = pagy(scope, limit: pagination_limit)
    end

    def destroy
      authorize_admin!(NewsletterSubscriber, :destroy?)

      subscriber = NewsletterSubscriber.find(params[:id])
      email = subscriber.email
      subscriber.destroy!
      audit!("newsletter_subscriber.deleted", subscriber, changeset: { "email" => email })
      redirect_to admin_newsletter_subscribers_path, notice: t("admin.newsletter.deleted")
    end

    private

    def filter_status(scope)
      case @status
      when "confirmed" then scope.confirmed
      when "unconfirmed" then scope.pending
      when "unsubscribed" then scope.where.not(unsubscribed_at: nil)
      else scope
      end
    end
  end
end
