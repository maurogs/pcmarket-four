module Api
  # Page/per_page pagination shared by every API collection. Business
  # collections keep their own default page sizes where the existing service
  # already paginates (ListingSearch, PcFinder).
  module Pagination
    DEFAULT_PER_PAGE = 24
    MAX_PER_PAGE = 100

    Result = Struct.new(:records, :pagy, keyword_init: true)

    module_function

    def call(scope, params:, default: DEFAULT_PER_PAGE, max: MAX_PER_PAGE)
      per_page = params[:per_page].to_i
      per_page = default if per_page <= 0
      per_page = [ per_page, max ].min

      count = scope.except(:order).count
      pages = [ (count.to_f / per_page).ceil, 1 ].max
      page = [ [ params[:page].to_i, 1 ].max, pages ].min
      pagy = Pagy.new(count: count, page: page, limit: per_page)

      records = scope.offset(pagy.offset).limit(pagy.limit)
      Result.new(records: records, pagy: pagy)
    end
  end
end
