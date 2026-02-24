class Setting < ApplicationRecord
  validates :key, presence: true, uniqueness: true

  def self.get(key, default = nil)
    find_by(key: key)&.value || default
  end

  def self.set(key, value)
    record = find_or_initialize_by(key: key)
    record.update!(value: value)
  end

  # Helpers for specific settings
  def self.google_places_api_key = get('google_places_api_key')
  def self.default_province       = get('default_province', 'Western Cape')
  def self.default_city           = get('default_city', 'Cape Town')
  def self.enabled_sources        = get('enabled_sources', 'yellow_pages,brabys').split(',')
  def self.audit_concurrency      = get('audit_concurrency', '5').to_i
end
