require 'nokogiri'
require 'httparty'

class Scrapers::BrabysScraper
  # Brabys.com is protected by Cloudflare and returns 403 for all automated
  # requests including on the homepage. Scraping is not possible without a
  # headless browser. This scraper is disabled — use Yellow Pages instead.

  def initialize(category:, location:, max_pages: 5)
    @category  = category
    @location  = location
    @max_pages = max_pages
  end

  def scrape
    Rails.logger.warn "[Brabys] Scraping disabled: Brabys.com blocks automated requests (Cloudflare 403). Use Yellow Pages or Google Places instead."
    0
  end

  # DISABLED — kept for reference only
  def scrape_disabled
    results = []
    (1..@max_pages).each do |page|
      url  = "https://www.brabys.com/search_results?q=#{CGI.escape(@category)}&location_value=#{CGI.escape(@location)}&page=#{page}"
      html = fetch(url)
      break if html.nil?

      doc      = Nokogiri::HTML(html)
      listings = doc.css('.result-item, .business-card, [class*="result"]')
      break if listings.empty?

      listings.each do |node|
        name    = node.at_css('h2, h3, .name, [class*="title"]')&.text&.strip
        phone   = node.at_css('.phone, [class*="phone"], [class*="tel"]')&.text&.strip
        address = node.at_css('.address, [class*="address"]')&.text&.strip
        website = node.at_css('a.website, a[href*="http"][target="_blank"]')&.[]('href')

        next if name.blank?

        results << {
          name:        name,
          phone:       phone,
          address:     address,
          website_url: website,
          city:        @location,
          source:      'brabys',
          category:    @category,
          scraped_at:  Time.current
        }
      end
    rescue => e
      Rails.logger.warn "[Brabys] Error on page #{page}: #{e.message}"
    end

    save_results(results)
    results.length
  end

  private

  def fetch(url)
    response = HTTParty.get(url, headers: default_headers, timeout: 15)
    return nil unless response.success?
    response.body
  rescue => e
    Rails.logger.warn "[Brabys] Fetch failed for #{url}: #{e.message}"
    nil
  end

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
      'User-Agent'      => 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
      'Accept'          => 'text/html,application/xhtml+xml,application/xml;q=0.9',
      'Accept-Language' => 'en-ZA,en;q=0.9'
    }
  end
end
