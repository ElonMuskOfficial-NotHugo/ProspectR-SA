require 'nokogiri'
require 'httparty'
require 'json'
require 'cgi'

class Scrapers::YellowPagesScraper
  BASE_URL = "https://www.yellowpages.co.za"

  # Yellow Pages SA uses Next.js with CSS modules (hashed class names).
  # Selectors verified against live HTML on 2026-02-24.
  CARD_SELECTOR    = "[class*='serviceResultCard_service_result_card__']"
  NAME_SELECTOR    = "h6"
  ADDRESS_SELECTOR = "p[class*='location_location_name__']"

  # fetch_details: true  = visit each business page to get phone + website (slower, ~0.3s/biz)
  # fetch_details: false = card data only, name+address (fast, good for bulk collection)
  def initialize(category:, location:, max_pages: 5, fetch_details: true)
    @category      = category.to_s.strip
    @location      = location.to_s.strip
    @max_pages     = max_pages
    @fetch_details = fetch_details
  end

  def scrape
    results = []

    (1..@max_pages).each do |page|
      url  = "#{BASE_URL}/search?what=#{CGI.escape(@category)}&where=#{CGI.escape(@location)}&page=#{page}"
      html = fetch(url)
      break if html.nil?

      doc   = Nokogiri::HTML(html)
      cards = doc.css(CARD_SELECTOR)
      Rails.logger.info "[YellowPages] Page #{page}: #{cards.length} cards at #{url}"
      break if cards.empty?

      cards.each do |card|
        name    = card.at_css(NAME_SELECTOR)&.text&.strip
        address = card.at_css(ADDRESS_SELECTOR)&.text&.strip
        detail_path = card.at_css('a')&.[]('href')

        next if name.blank?

        city = extract_city(address) || @location.split(',').first.strip.titleize

        phone, website = if @fetch_details
          result = fetch_detail_data(detail_path)
          sleep(0.3)
          result
        else
          [nil, nil]
        end

        results << {
          name:        name,
          phone:       phone,
          address:     address,
          website_url: website,
          city:        city,
          province:    extract_province(address),
          source:      'yellow_pages',
          category:    @category,
          scraped_at:  Time.current
        }
      end

    rescue => e
      Rails.logger.warn "[YellowPages] Error on page #{page}: #{e.message}"
    end

    new_count = save_results(results)
    Rails.logger.info "[YellowPages] Scraped #{results.length} total, #{new_count} new"
    new_count
  end

  private

  # Fetch phone + business website from the detail page JSON-LD.
  def fetch_detail_data(path)
    return [nil, nil] if path.blank?
    url  = path.start_with?('http') ? path : "#{BASE_URL}#{path}"
    html = fetch(url)
    return [nil, nil] if html.nil?

    doc = Nokogiri::HTML(html)
    phone   = nil
    website = nil

    doc.css("script[type='application/ld+json']").each do |script|
      data = JSON.parse(script.text) rescue next
      next unless data.is_a?(Hash)

      if data['telephone'].present?
        phone = data['telephone'].to_s.gsub(/\s+/, '')
      end

      # Find an external website — skip yep.co.za / yellowpages.co.za URLs
      raw_url = data['url'].to_s
      if raw_url.present? && raw_url !~ /yep\.co\.za|yellowpages\.co\.za/i
        website = raw_url.start_with?('http') ? raw_url : "https://#{raw_url}"
      end

      # Also check sameAs array
      Array(data['sameAs']).each do |u|
        next if u =~ /yep\.co\.za|yellowpages\.co\.za|facebook|instagram|twitter|linkedin/i
        if u.start_with?('http')
          website ||= u
        end
      end
    end

    [phone, website]
  rescue => e
    Rails.logger.warn "[YellowPages] Detail fetch failed for #{path}: #{e.message}"
    [nil, nil]
  end

  def fetch(url)
    response = HTTParty.get(url, headers: default_headers, timeout: 20, follow_redirects: true)
    return nil unless response.success?
    response.body
  rescue => e
    Rails.logger.warn "[YellowPages] Fetch failed for #{url}: #{e.message}"
    nil
  end

  # Best-effort: address is "Street, Suburb, City PostalCode, Province"
  def extract_city(address)
    return nil if address.blank?
    parts = address.split(',').map(&:strip)
    # City is typically the third segment (index 2) or second-to-last before province
    return parts[-2]&.gsub(/\d+/, '')&.strip&.presence if parts.length >= 3
    parts.last&.gsub(/\d+/, '')&.strip&.presence
  end

  SA_PROVINCES = ['Gauteng', 'Limpopo', 'Mpumalanga', 'North West', 'Northern Cape',
                  'Free State', 'KwaZulu-Natal', 'Eastern Cape', 'Western Cape'].freeze

  def extract_province(address)
    return nil if address.blank?
    SA_PROVINCES.find { |p| address.include?(p) }
  end

  def save_results(results)
    new_count = 0
    results.each do |attrs|
      biz = Business.find_or_initialize_by(name: attrs[:name], city: attrs[:city])
      if biz.new_record?
        biz.assign_attributes(attrs)
        biz.save!
        new_count += 1
      end
    rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid
      # skip duplicates / validation failures
    end
    new_count
  end

  def default_headers
    {
      'User-Agent'      => 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
      'Accept'          => 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      'Accept-Language' => 'en-ZA,en;q=0.9',
      'Cache-Control'   => 'no-cache'
    }
  end
end
