class LegalPagesController < ApplicationController
  def show
    @legal_page = LegalPage.published.for_locale(I18n.locale).find_by(slug: params[:slug]) ||
                  LegalPage.published.find_by(slug: params[:slug])
    raise ActiveRecord::RecordNotFound if @legal_page.nil?
  end
end
