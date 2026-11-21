class OrderMailer < ApplicationMailer
  helper ApplicationHelper

  def placed_buyer(order)
    @order = order
    @guest_url = order.guest? ? order_url(order, token: order.guest_access_token, locale: locale_for(order)) : order_url(order, locale: locale_for(order))

    I18n.with_locale(locale_for(order)) do
      mail(to: order.buyer_email.presence || order.buyer&.email,
           subject: t("orders.mailer.buyer.subject", number: order.number, site: site_name))
    end
  end

  def placed_seller(order)
    @order = order
    @seller_url = seller_orders_url(locale: locale_for(order))

    I18n.with_locale(locale_for(order)) do
      mail(to: order.seller.email,
           subject: t("orders.mailer.seller.subject", number: order.number, site: site_name))
    end
  end

  def paid_buyer(order, locale: nil)
    deliver_event(order, :paid_buyer, locale: locale, to: buyer_email(order), cta: :buyer)
  end

  def paid_seller(order, locale: nil)
    deliver_event(order, :paid_seller, locale: locale, to: order.seller.email, cta: :seller)
  end

  def shipped_buyer(order, locale: nil)
    deliver_event(order, :shipped_buyer, locale: locale, to: buyer_email(order), cta: :buyer)
  end

  def delivered_buyer(order, locale: nil)
    deliver_event(order, :delivered_buyer, locale: locale, to: buyer_email(order), cta: :buyer)
  end

  def completed_buyer(order, locale: nil)
    deliver_event(order, :completed_buyer, locale: locale, to: buyer_email(order), cta: :buyer)
  end

  def cancelled_buyer(order, locale: nil)
    deliver_event(order, :cancelled_buyer, locale: locale, to: buyer_email(order), cta: :buyer)
  end

  def cancelled_seller(order, locale: nil)
    deliver_event(order, :cancelled_seller, locale: locale, to: order.seller.email, cta: :seller)
  end

  def dispute_seller(order, locale: nil)
    deliver_event(order, :dispute_seller, locale: locale, to: order.seller.email, cta: :seller)
  end

  def late_shipment_seller(order, locale: nil)
    deliver_event(order, :late_shipment_seller, locale: locale, to: order.seller.email, cta: :seller)
  end

  def dispute_admin(order, to:, locale: nil)
    deliver_event(order, :dispute_admin, locale: locale, to: to, cta: nil)
  end

  private

  def deliver_event(order, event, locale:, to:, cta:)
    @order = order
    @event = event
    @locale = locale_for(order, locale)
    @tracking_url = order.tracking_url
    @guest_url = order.guest? ? order_url(order, token: order.guest_access_token, locale: @locale) : nil
    @cta_url = cta_url_for(order, cta)

    I18n.with_locale(@locale) do
      dispute_event = order.order_events.where(kind: "dispute_opened").last
      @heading = t("orders.mailer.events.#{event}.title")
      @intro = t(
        "orders.mailer.events.#{event}.intro",
        number: order.number,
        store: order.store&.name || order.seller.display_name,
        carrier: carrier_label(order.carrier),
        tracking: order.tracking_number.to_s,
        days: Setting.get("seller_ship_deadline_days", 3).to_i,
        reason: dispute_event&.data&.dig("reason").to_s,
        details: dispute_event&.data&.dig("details").to_s
      )
      @cta_label = cta ? t("orders.mailer.events.#{event}.cta") : nil
      @recipient_name = recipient_name(order, cta)

      mail(to: to,
           subject: t("orders.mailer.events.#{event}.subject", number: order.number, site: site_name),
           template_name: "event")
    end
  end

  def cta_url_for(order, cta)
    case cta
    when :buyer then buyer_order_url(order)
    when :seller then seller_order_url(order, locale: @locale)
    end
  end

  def buyer_order_url(order)
    if order.guest?
      order_url(order, token: order.guest_access_token, locale: @locale)
    else
      order_url(order, locale: @locale)
    end
  end

  def recipient_name(order, cta)
    if cta == :seller
      order.seller.display_name
    else
      order.ship_name.presence || order.buyer&.full_name || order.buyer_email.to_s
    end
  end

  def carrier_label(carrier)
    return nil if carrier.blank?

    I18n.t("orders.carriers.#{carrier}", default: carrier)
  end

  def buyer_email(order)
    order.buyer_email.presence || order.buyer&.email
  end

  def locale_for(order, override = nil)
    candidate = override.presence || order.locale
    I18n.available_locales.map(&:to_s).include?(candidate.to_s) ? candidate : I18n.default_locale
  end

  def site_name
    Setting.get("site_name", "PCMarket")
  end
end
