# Per-request / per-task attributes. The demo seeder sets `seeding` so models
# and mailers skip broadcasts, notifications and outbound email fan-out.
class Current < ActiveSupport::CurrentAttributes
  attribute :seeding, :boolean, default: false
end
