class Business < ApplicationRecord
  has_one :audit_result, dependent: :destroy

  validates :name, presence: true
  validates :name, uniqueness: { scope: :city, case_sensitive: false, message: "already exists in this city" }

  SOURCES = %w[yellow_pages brabys google_places cipc manual].freeze
  validates :source, inclusion: { in: SOURCES }

  scope :needs_audit,    -> { where(needs_audit: true) }
  scope :has_website,    -> { where.not(website_url: [nil, '']) }
  scope :no_website,     -> { where(website_url: [nil, '']) }
  scope :by_city,        ->(city) { where(city: city) }
  scope :by_province,    ->(prov) { where(province: prov) }
  scope :by_source,      ->(src)  { where(source: src) }
  scope :recently_added, -> { order(created_at: :desc) }

  def has_website?
    website_url.present?
  end

  def audit_score
    audit_result&.score || 0
  end

  def prospect_quality
    score = audit_score
    return 'no_website' unless has_website?
    return 'high'   if score >= 70
    return 'medium' if score >= 40
    'low'
  end
end
