# Default settings
[
  { key: 'default_province',      value: 'Western Cape' },
  { key: 'default_city',          value: 'Cape Town' },
  { key: 'default_category',      value: 'restaurant' },
  { key: 'enabled_sources',       value: 'yellow_pages,brabys' },
  { key: 'audit_concurrency',     value: '5' },
  { key: 'google_places_api_key', value: '' }
].each do |s|
  Setting.find_or_create_by(key: s[:key]) { |r| r.value = s[:value] }
end

puts "Seeds loaded: #{Setting.count} settings"
