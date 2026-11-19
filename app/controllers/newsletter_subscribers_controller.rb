class NewsletterSubscribersController < ApplicationController
  # Placeholder: newsletter persistence lands in a later phase. Accept the
  # request and show a friendly confirmation so the UI can be tested.
  def create
    redirect_back fallback_location: root_path,
                  notice: t("newsletter.coming_soon")
  end
end
