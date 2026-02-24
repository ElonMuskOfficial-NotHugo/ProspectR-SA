class AuditResult < ApplicationRecord
  belongs_to :business

  after_save :update_business_needs_audit

  # Score 0-100 — higher = more overhaul needed (better prospect for you)
  # 20 pts: no website
  # 20 pts: no SSL
  # 20 pts: not mobile friendly
  # 15 pts: old/no copyright year (before 2020)
  # 15 pts: known outdated CMS (Joomla, old WP theme)
  # 10 pts: slow load (>3s)

  OUTDATED_CMS = %w[joomla drupal blogger weebly wix-old flash silverlight].freeze

  def issues_list
    return [] if issues.blank?
    JSON.parse(issues) rescue []
  end

  def issues_list=(arr)
    self.issues = arr.to_json
  end

  def self.calculate_score(attrs)
    score = 0
    issues = []

    unless attrs[:has_website]
      score += 20
      issues << "No website found"
    end

    unless attrs[:has_ssl]
      score += 20
      issues << "No SSL/HTTPS"
    end

    unless attrs[:is_mobile_friendly]
      score += 20
      issues << "Not mobile-friendly"
    end

    yr = attrs[:copyright_year]
    if yr.nil? || yr < 2020
      score += 15
      issues << "Outdated copyright year (#{yr || 'none'})"
    end

    cms = attrs[:cms_detected].to_s.downcase
    if OUTDATED_CMS.any? { |c| cms.include?(c) }
      score += 15
      issues << "Outdated CMS detected: #{attrs[:cms_detected]}"
    end

    load_ms = attrs[:load_time_ms].to_i
    if load_ms > 3000
      score += 10
      issues << "Slow load time (#{load_ms}ms)"
    end

    [score.clamp(0, 100), issues]
  end

  private

  def update_business_needs_audit
    business.update_column(:needs_audit, false)
  end
end
