json.data @tree do |node|
  json.id node[:id]
  json.slug node[:slug]
  json.name node[:name]
  json.path node[:path_slugs]
  json.icon node[:icon]
  json.position node[:position]
  json.listings_count node[:listings_count]
  json.children node[:children] do |child|
    json.id child[:id]
    json.slug child[:slug]
    json.name child[:name]
    json.path child[:path_slugs]
    json.icon child[:icon]
    json.position child[:position]
    json.listings_count child[:listings_count]
    json.children child[:children] do |grandchild|
      json.id grandchild[:id]
      json.slug grandchild[:slug]
      json.name grandchild[:name]
      json.path grandchild[:path_slugs]
      json.listings_count grandchild[:listings_count]
      json.children []
    end
  end
end
json.meta({})
