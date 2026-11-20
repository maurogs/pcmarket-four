# Per-request global state. Never store objects with lifecycle issues here
# unless they are request-scoped. Reset automatically between requests by
# Rails' reloader for tests; set from a controller before_action.
class Current < ActiveSupport::CurrentAttributes
  attribute :country, :user, :cart
end
