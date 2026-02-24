require 'httparty'
require 'nokogiri'

# Scrapes CIPC (Companies and Intellectual Property Commission) public search
# https://efiling.cipc.co.za — Note: CIPC has rate limiting; scrape respectfully.
class Scrapers::CipcScraper
  SEARCH_URL = "https://efiling.cipc.co.za/FindEnterprise.aspx"

  def initialize(keyword:, location: nil)
    @keyword  = keyword
    @location = location
  end

  def scrape
    results = []

    response = HTTParty.get(
      SEARCH_URL,
      query:   { searchvalue: @keyword },
      headers: default_headers,
      timeout: 20
    )

    return 0 unless response.success?

    doc  = Nokogiri::HTML(response.body)
    rows = doc.css('table tr').drop(1) # skip header row

    rows.each do |row|
      cells = row.css('td').map { |td| td.text.strip }
      next if cells.empty?

      name   = cells[0]
      reg_no = cells[1]
      status = cells[2]

      next if name.blank? || status&.downcase != 'in business'

      results << {
        name:       name,
        address:    "Reg No: #{reg_no}",
        city:       @location || "Unknown",
        source:     'cipc',
        category:   @keyword,
        scraped_at: Time.current
      }
    end

    save_results(results)
    results.length
  rescue => e
    Rails.logger.warn "[CIPC] Scrape failed: #{e.message}"
    0
  end

  private

  def save_results(results)
    results.each do |attrs|
      Business.find_or_create_by(name: attrs[:name], city: attrs[:city]) do |b|
        b.assign_attributes(attrs)
      end
    rescue ActiveRecord::RecordNotUnique
      # skip duplicates
    end
  end

  def default_headers
    {
      'User-Agent' => 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
      'Accept'     => 'text/html,application/xhtml+xml'
    }
  end
end
