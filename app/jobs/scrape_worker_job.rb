class ScrapeWorkerJob < ApplicationJob
  queue_as :default

  SCRAPER_MAP = {
    'yellow_pages'  => Scrapers::YellowPagesScraper,
    'brabys'        => Scrapers::BrabysScraper,
    'google_places' => Scrapers::GooglePlacesScraper,
    'cipc'          => Scrapers::CipcScraper
  }.freeze

  def perform(scrape_job_id, fetch_details: true, max_pages: 5)
    job = ScrapeJob.find(scrape_job_id)
    job.mark_running!

    scraper_class = SCRAPER_MAP[job.source]
    raise "Unknown source: #{job.source}" unless scraper_class

    count = if job.source == 'yellow_pages'
      scraper_class.new(
        category:      job.category,
        location:      job.location,
        max_pages:     max_pages,
        fetch_details: fetch_details
      ).scrape
    elsif job.source == 'cipc'
      scraper_class.new(keyword: job.category, location: job.location).scrape
    else
      scraper_class.new(category: job.category, location: job.location).scrape
    end

    job.mark_completed!(count)
  rescue => e
    ScrapeJob.find_by(id: scrape_job_id)&.mark_failed!(e.message)
    raise
  end
end
