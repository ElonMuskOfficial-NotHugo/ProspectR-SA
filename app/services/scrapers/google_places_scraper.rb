require 'httparty'

class Scrapers::GooglePlacesScraper
  BASE_URL    = "https://maps.googleapis.com/maps/api"
  DETAILS_URL = "#{BASE_URL}/place/details/json"
  SEARCH_URL  = "#{BASE_URL}/place/textsearch/json"

  def initialize(category:, location:, api_key: nil)
    @category = category
    @location = location
    @api_key  = api_key || Setting.google_places_api_key
  end

  def scrape
    return 0 if @api_key.blank?

    results    = []
    next_token = nil

    loop do
      params = {
        query:  "#{@category} in #{@location}, South Africa",
        key:    @api_key,
        region: 'za'
      }
      params[:pagetoken] = next_token if next_token

      data = fetch(SEARCH_URL, params)
      break if data.nil? || data['status'] != 'OK'

      data['results'].each do |place|
        details = fetch_details(place['place_id'])
        next unless details

        results << {
          name:        place['name'],
          address:     place['formatted_address'],
          phone:       details.dig('formatted_phone_number'),
          website_url: details.dig('website'),
          city:        @location,
          source:      'google_places',
          category:    @category,
          scraped_at:  Time.current
        }
      end

      next_token = data['next_page_token']
      break if next_token.blank?
      sleep 2 # Google requires a short delay before using next_page_token
    end

    save_results(results)
    results.length
  end

  private

  def fetch(url, params)
    response = HTTParty.get(url, query: params, timeout: 15)
    return nil unless response.success?
    JSON.parse(response.body)
  rescue => e
    Rails.logger.warn "[GooglePlaces] Fetch failed: #{e.message}"
    nil
  end

  def fetch_details(place_id)
    data = fetch(DETAILS_URL, {
      place_id: place_id,
      fields:   'formatted_phone_number,website',
      key:      @api_key
    })
    data&.dig('result')
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
end
