json.data do
  json.id @block.id
  json.blocker_id @block.blocker_id
  json.blocked_id @block.blocked_id
  json.created_at @block.created_at.iso8601
end
json.meta({})
