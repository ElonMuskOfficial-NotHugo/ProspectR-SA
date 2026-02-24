require 'httparty'
require 'nokogiri'

class WebsiteAuditor
  OUTDATED_CMS = {
    'wp-content'       => 'WordPress',
    'joomla'           => 'Joomla',
    'drupal'           => 'Drupal',
    'wp-includes'      => 'WordPress',
    '/sites/default'   => 'Drupal',
    'generator.*joomla'=> 'Joomla',
    'blogger.com'      => 'Blogger',
    'weebly.com'       => 'Weebly',
    'wix.com'          => 'Wix'
  }.freeze

  OUTDATED_CMS_NAMES = %w[Joomla Drupal Blogger Weebly].freeze

  def initialize(business)
    @business = business
  end

  def audit
    url = @business.website_url

    if url.blank?
      return save_result(
        has_website:       false,
        has_ssl:           false,
        is_mobile_friendly: false,
        cms_detected:      nil,
        load_time_ms:      nil,
        copyright_year:    nil
      )
    end

    url = "http://#{url}" unless url.start_with?('http')

    start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    response   = fetch(url)
    elapsed_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) * 1000).round

    if response.nil?
      return save_result(
        has_website:       true,
        has_ssl:           false,
        is_mobile_friendly: false,
        cms_detected:      'unreachable',
        load_time_ms:      nil,
        copyright_year:    nil
      )
    end

    final_url  = response.request.last_uri.to_s
    html       = response.body.to_s
    doc        = Nokogiri::HTML(html)

    save_result(
      has_website:        true,
      has_ssl:            final_url.start_with?('https'),
      is_mobile_friendly: mobile_friendly?(doc),
      cms_detected:       detect_cms(html),
      load_time_ms:       elapsed_ms,
      copyright_year:     extract_copyright_year(doc)
    )
  rescue => e
    Rails.logger.warn "[Auditor] #{@business.name}: #{e.message}"
    nil
  end

  private

  def fetch(url)
    HTTParty.get(
      url,
      timeout:          15,
      follow_redirects: true,
      headers: {
        'User-Agent' => 'Mozilla/5.0 (compatible; ProspectRBot/1.0)'
      }
    )
  rescue => e
    Rails.logger.warn "[Auditor] Fetch failed for #{url}: #{e.message}"
    nil
  end

  def mobile_friendly?(doc)
    viewport = doc.at_css('meta[name="viewport"]')
    return false unless viewport
    content = viewport['content'].to_s.downcase
    content.include?('width=device-width')
  end

  def detect_cms(html)
    lower = html.downcase
    OUTDATED_CMS.each do |pattern, name|
      return name if lower.match?(pattern)
    end
    nil
  end

  def extract_copyright_year(doc)
    text = doc.css('footer, #footer, .footer, [class*="footer"]').map(&:text).join(' ')
    text = doc.at_css('body')&.text if text.blank?
    match = text&.match(/©\s*(\d{4})/)
    match ? match[1].to_i : nil
  end

  def save_result(attrs)
    score, issues = AuditResult.calculate_score(attrs)

    result = @business.audit_result || @business.build_audit_result
    result.assign_attributes(attrs.merge(
      score:      score,
      issues:     issues.to_json,
      audited_at: Time.current
    ))
    result.save!
    result
  end
end
