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

      doc       = Nokogiri::HTML(html)
      page_data = parse_next_data(doc)
      cards_raw = page_data&.dig("props", "pageProps", "results") || []

      # Fall back to CSS selector parsing if __NEXT_DATA__ has no results
      if cards_raw.empty?
        cards_raw = doc.css(CARD_SELECTOR).map do |card|
          name    = card.at_css(NAME_SELECTOR)&.text&.strip
          address = card.at_css(ADDRESS_SELECTOR)&.text&.strip
          href    = card.at_css('a')&.[]('href')
          { "name" => name, "address_text" => address, "detail_href" => href }
        end.reject { |c| c["name"].blank? }
      end

      Rails.logger.info "[YellowPages] Page #{page}: #{cards_raw.length} results at #{url}"
      break if cards_raw.empty?

      cards_raw.each do |card|
        # Data from __NEXT_DATA__ results array
        name    = card["name"].to_s.strip
        next if name.blank?

        addr_obj = card["address"]
        address  = if addr_obj.is_a?(Hash)
          [addr_obj["address1"], addr_obj["locality"], addr_obj["city"],
           addr_obj["postcode"], addr_obj["province"]].compact.join(", ")
        else
          card["address_text"].to_s
        end

        city     = addr_obj&.dig("city") || extract_city(address) || @location.split(',').first.strip.titleize
        province = addr_obj&.dig("province") || extract_province(address)

        detail_path = card["detail_href"] ||
                      (card["store_id"].present? ? "/biz/store/#{name.parameterize}/#{card['store_id']}" : nil)

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
          province:    province,
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

  # Fetch phone + business website from the detail page __NEXT_DATA__ blob.
  def fetch_detail_data(path)
    return [nil, nil] if path.blank?
    url  = path.start_with?('http') ? path : "#{BASE_URL}#{path}"
    html = fetch(url)
    return [nil, nil] if html.nil?

    doc   = Nokogiri::HTML(html)
    store = parse_next_data(doc)&.dig("props", "pageProps", "storeData")
    return [nil, nil] if store.nil?

    # phone is an array of strings e.g. ["0217611528"]
    phone = Array(store["phone"]).first&.to_s&.gsub(/\s+/, '')&.presence

    # website is a plain string — may lack scheme
    raw_url = store["website"].to_s.strip
    website = if raw_url.present? && raw_url !~ /yep\.co\.za|yellowpages\.co\.za/i
      raw_url.start_with?('http') ? raw_url : "https://#{raw_url}"
    end

    [phone, website]
  rescue => e
    Rails.logger.warn "[YellowPages] Detail fetch failed for #{path}: #{e.message}"
    [nil, nil]
  end

  # Parse the Next.js __NEXT_DATA__ JSON embedded in every page.
  def parse_next_data(doc)
    script = doc.at_css("script#__NEXT_DATA__")
    return nil unless script
    JSON.parse(script.text)
  rescue JSON::ParserError
    nil
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
      else
        # Backfill phone and website if they were missing from a previous scrape
        updates = {}
        updates[:phone]       = attrs[:phone]       if attrs[:phone].present?       && biz.phone.blank?
        updates[:website_url] = attrs[:website_url] if attrs[:website_url].present? && biz.website_url.blank?
        biz.update!(updates) if updates.any?
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
