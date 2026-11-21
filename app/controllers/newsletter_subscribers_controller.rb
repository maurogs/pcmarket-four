class NewsletterSubscribersController < ApplicationController
  def create
    result = NewsletterSubscription.new.subscribe(
      email: params[:email], locale: I18n.locale
    )
    @success = result.status != :invalid
    @message = message_for(result.status)

    respond_to do |format|
      format.turbo_stream { render :create }
      format.html do
        redirect_back fallback_location: root_path,
                      notice: (@success ? @message : nil),
                      alert: (@success ? nil : @message)
      end
    end
  end

  def confirm
    subscriber = NewsletterSubscriber.find_by(token: params[:token])
    if subscriber
      subscriber.confirm!
      redirect_to root_path(locale: subscriber.locale), notice: t("newsletter.confirm.success")
    else
      redirect_to root_path, alert: t("newsletter.confirm.invalid")
    end
  end

  private

  def message_for(status)
    case status
    when :created then t("newsletter.subscribe.success")
    when :already_confirmed then t("newsletter.subscribe.already_confirmed")
    else t("newsletter.subscribe.invalid")
    end
  end
end
