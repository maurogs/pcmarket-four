json.data do
  json.id @report.id
  json.reportable_type @report.reportable_type
  json.reportable_id @report.reportable_id
  json.reason @report.reason
  json.details @report.details
  json.status @report.status
  json.created_at @report.created_at.iso8601
end
json.meta({})
