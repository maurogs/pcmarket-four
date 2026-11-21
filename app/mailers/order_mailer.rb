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

  private

  def locale_for(order)
    I18n.available_locales.map(&:to_s).include?(order.locale.to_s) ? order.locale : I18n.default_locale
  end

  def site_name
    Setting.get("site_name", "PCMarket")
  end
end
