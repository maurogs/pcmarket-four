json.data do
  json.id @device.id
  json.platform @device.platform
  json.app_version @device.app_version
  json.last_seen_at @device.last_seen_at&.iso8601
  json.created_at @device.created_at.iso8601
end
json.meta({})
