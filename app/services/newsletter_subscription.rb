class NewsletterSubscription
  Result = Data.define(:status, :subscriber)

  def subscribe(email:, locale:)
    subscriber = NewsletterSubscriber.find_or_initialize_by(email: email.to_s.strip.downcase)
    subscriber.locale = locale

    if subscriber.persisted? && subscriber.confirmed?
      Result.new(:already_confirmed, subscriber)
    elsif subscriber.save
      NewsletterMailer.confirmation(subscriber).deliver_later
      Result.new(subscriber.confirmed? ? :already_confirmed : :created, subscriber)
    else
      Result.new(:invalid, subscriber)
    end
  end
end
