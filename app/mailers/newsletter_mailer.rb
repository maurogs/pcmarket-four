class NewsletterMailer < ApplicationMailer
  default from: "PCMarket <no-reply@pcmarket.es>"

  def confirmation(subscriber)
    @subscriber = subscriber

    I18n.with_locale(subscriber.locale) do
      @confirm_url = confirm_newsletter_url(token: subscriber.token, locale: subscriber.locale)
      mail(to: subscriber.email, subject: t("newsletter.mailer.subject"))
    end
  end
end
