require 'nokogiri'
require 'httparty'

class Scrapers::YellowPagesScraper
  BASE_URL = "https://www.yellowpages.co.za"

  def initialize(category:, location:, max_pages: 5)
    @category  = category.to_s.downcase.gsub(/\s+/, '-')
    @location  = location.to_s.downcase.gsub(/\s+/, '-')
    @max_pages = max_pages
  end

  def scrape
    results = []
    (1..@max_pages).each do |page|
      url  = "#{BASE_URL}/search?what=#{CGI.escape(@category)}&where=#{CGI.escape(@location)}&page=#{page}"
      html = fetch(url)
      break if html.nil?

      doc      = Nokogiri::HTML(html)
      listings = doc.css('.listing, .business-listing, [class*="listing"]')
      break if listings.empty?

      listings.each do |node|
        name    = node.at_css('[class*="name"], h2, h3')&.text&.strip
        phone   = node.at_css('[class*="phone"], .telephone')&.text&.strip
        address = node.at_css('[class*="address"], .street')&.text&.strip
        website = node.at_css('a[href*="http"]')&.[]('href')

        next if name.blank?

        results << {
          name:        name,
          phone:       phone,
          address:     address,
          website_url: external_url(website),
          city:        @location.titleize,
          source:      'yellow_pages',
          category:    @category,
          scraped_at:  Time.current
        }
      end
    rescue => e
      Rails.logger.warn "[YellowPages] Error on page #{page}: #{e.message}"
    end

    save_results(results)
    results.length
  end

  private

  def fetch(url)
    response = HTTParty.get(url, headers: default_headers, timeout: 15, follow_redirects: true)
    return nil unless response.success?
    response.body
  rescue => e
    Rails.logger.warn "[YellowPages] Fetch failed for #{url}: #{e.message}"
    nil
  end

  def external_url(href)
    return nil if href.blank?
    return href if href.start_with?('http')
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
      'Accept'          => 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      'Accept-Language' => 'en-ZA,en;q=0.9'
    }
  end
end
