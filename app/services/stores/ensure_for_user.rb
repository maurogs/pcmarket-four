module Stores
  # Lazily creates (and memoizes) the one storefront a user owns. Sellers
  # never pick their store name up-front — it starts as their username.
  class EnsureForUser
    def self.call(user)
      new(user).call
    end

    def initialize(user)
      @user = user
    end

    def call
      user.store || user.create_store!(name: user.username)
    end

    private

    attr_reader :user
  end
end
