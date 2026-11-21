class UserDataExport
  def initialize(user)
    @user = user
  end

  def as_json
    {
      exported_at: Time.current.iso8601,
      user: user_payload,
      addresses: user.addresses.map { |address| address_payload(address) },
      listings: user.listings.includes(:category).map { |listing| listing_payload(listing) },
      orders: orders.map { |order| order_payload(order) },
      favourites: user.favorites.includes(listing: :store).map { |favorite| favorite_payload(favorite) },
      reviews: user.reviews.map { |review| review_payload(review) },
      saved_searches: user.saved_searches.map { |search| saved_search_payload(search) }
    }
  end

  private

  attr_reader :user

  def user_payload
    {
      id: user.id,
      email: user.email,
      username: user.username,
      first_name: user.first_name,
      last_name: user.last_name,
      phone: user.phone,
      locale: user.locale,
      country_code: user.country_code,
      created_at: user.created_at.iso8601
    }
  end

  def address_payload(address)
    {
      full_name: address.full_name,
      line1: address.line1,
      line2: address.line2,
      city: address.city,
      postal_code: address.postal_code,
      country_code: address.country_code,
      phone: address.phone,
      default: address.default
    }
  end

  def listing_payload(listing)
    {
      id: listing.id,
      title: listing.title,
      description: listing.description,
      price_cents: listing.price_cents,
      currency: listing.currency,
      status: listing.status,
      category: listing.category&.name,
      created_at: listing.created_at.iso8601
    }
  end

  def orders
    Order.where("buyer_id = :id OR seller_id = :id", id: user.id).includes(:order_items)
  end

  def order_payload(order)
    {
      number: order.number,
      role: order.buyer_id == user.id ? "buyer" : "seller",
      status: order.status,
      total_cents: order.total_cents,
      currency: order.currency,
      created_at: order.created_at.iso8601,
      items: order.order_items.map { |item| { title: item.title_snapshot, quantity: item.quantity } }
    }
  end

  def favorite_payload(favorite)
    {
      listing_id: favorite.listing_id,
      listing_title: favorite.listing&.title,
      store: favorite.listing&.store&.name,
      created_at: favorite.created_at.iso8601
    }
  end

  def review_payload(review)
    {
      order_id: review.order_id,
      store_id: review.store_id,
      rating: review.rating,
      body: review.body,
      created_at: review.created_at.iso8601
    }
  end

  def saved_search_payload(saved_search)
    {
      name: saved_search.name,
      filters: saved_search.filters,
      created_at: saved_search.created_at.iso8601
    }
  end
end
