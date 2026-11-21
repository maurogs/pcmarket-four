class SearchSuggestionsController < ApplicationController
  def index
    @results = SearchSuggestions.new(locale: I18n.locale).call(params[:q])
    render partial: "search_suggestions/results", locals: { results: @results }, layout: false
  end
end
