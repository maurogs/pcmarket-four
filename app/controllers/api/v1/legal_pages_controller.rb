module Api
  module V1
    class LegalPagesController < BaseController
      def show
        country = Country.enabled.find_by(code: params[:country].to_s.upcase) ||
                  Country.enabled.find_by(code: "ES")
        raise ActiveRecord::RecordNotFound if country.blank?

        @legal_page = LegalPage.resolve(country: country, locale: I18n.locale, slug: params[:slug])
        raise ActiveRecord::RecordNotFound if @legal_page.blank?

        cache_public_read!(@legal_page, extra: [ country.code, I18n.locale ])
        return if performed?

        render :show, formats: :json
      end
    end
  end
end
