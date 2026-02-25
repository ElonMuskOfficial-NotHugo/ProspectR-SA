class BulkScrapeJob < ApplicationJob
  queue_as :default

  # Common SA cities to cycle through
  SA_CITIES = [
    'Cape Town', 'Johannesburg', 'Pretoria', 'Durban', 'Port Elizabeth',
    'Bloemfontein', 'East London', 'Polokwane', 'Nelspruit', 'George',
    'Rustenburg', 'Pietermaritzburg', 'Kimberley', 'Witbank', 'Welkom',
    'Stellenbosch', 'Paarl', 'Knysna', 'Mossel Bay', 'Worcester'
  ].freeze

  # Business types most likely to need a website overhaul — SMBs with walk-in / call-in trade
  SMB_CATEGORIES = [
    'plumber', 'electrician', 'accountant', 'attorney', 'dentist', 'doctor',
    'salon', 'mechanic', 'builder', 'photographer', 'florist', 'bakery',
    'cleaning service', 'landscaping', 'pest control', 'locksmith',
    'estate agent', 'physiotherapist', 'optometrist', 'gym', 'guesthouse',
    'catering', 'wedding venue', 'printer', 'insurance broker', 'pharmacist',
    'restaurant', 'hardware store', 'furniture store', 'clothing store'
  ].freeze

  def perform(cities: nil, categories: nil, pages_per_combo: 2)
    cities     = (cities     || SA_CITIES).first(20)
    categories = (categories || SMB_CATEGORIES).first(30)

    total_jobs   = 0
    total_combos = cities.length * categories.length

    Rails.logger.info "[BulkScrape] Starting #{total_combos} city×category combinations"

    cities.each do |city|
      categories.each do |category|
        job = ScrapeJob.create!(
          source:   'yellow_pages',
          category: category,
          location: city,
          status:   'pending'
        )

        # fetch_details: false = fast card-only scraping, no per-business HTTP requests
        ScrapeWorkerJob.perform_later(job.id, fetch_details: false, max_pages: pages_per_combo)
        total_jobs += 1

        # Small stagger to avoid hammering the server
        sleep(0.1)
      end
    end

    Rails.logger.info "[BulkScrape] Queued #{total_jobs} scrape jobs"
    total_jobs
  end
end
