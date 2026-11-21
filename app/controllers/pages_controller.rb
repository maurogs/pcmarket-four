class PagesController < ApplicationController
  before_action :set_page_key

  def sell
  end

  def trust
  end

  def help
  end

  def about
  end

  private

  def set_page_key
    @page_key = action_name
  end
end
