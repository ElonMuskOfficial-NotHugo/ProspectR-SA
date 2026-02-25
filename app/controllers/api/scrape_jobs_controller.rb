module Api
  class ScrapeJobsController < ApplicationController
    def index
      jobs = ScrapeJob.recent.limit(50)
      render json: jobs.map { |j| serialize(j) }
    end

    def create
      sources = Array(params[:sources] || params[:source])
      sources = ScrapeJob::SOURCES if sources.empty?

      category = params[:category].presence || Setting.get('default_category', 'restaurant')
      location = params[:location].presence || Setting.default_city

      created_jobs = sources.map do |source|
        next unless ScrapeJob::SOURCES.include?(source)
        job = ScrapeJob.create!(source: source, category: category, location: location)
        ScrapeWorkerJob.perform_later(job.id)
        serialize(job)
      end.compact

      render json: { jobs: created_jobs }, status: :created
    end

    def bulk
      cities     = Array(params[:cities]).reject(&:blank?).presence || BulkScrapeJob::SA_CITIES.first(10)
      categories = Array(params[:categories]).reject(&:blank?).presence || BulkScrapeJob::SMB_CATEGORIES.first(15)
      pages      = (params[:pages_per_combo] || 2).to_i.clamp(1, 5)

      total_combos = cities.length * categories.length
      render json: { error: 'Too many combinations (max 200)' }, status: :unprocessable_entity and return if total_combos > 200

      BulkScrapeJob.perform_later(cities: cities, categories: categories, pages_per_combo: pages)

      render json: {
        message:     "Bulk scrape queued: #{total_combos} city×category combinations",
        cities:      cities.length,
        categories:  categories.length,
        total_combos: total_combos,
        estimated_results: total_combos * pages * 10
      }, status: :accepted
    end

    def show
      render json: serialize(ScrapeJob.find(params[:id]))
    rescue ActiveRecord::RecordNotFound
      render json: { error: 'Not found' }, status: :not_found
    end

    private

    def serialize(j)
      {
        id:             j.id,
        source:         j.source,
        category:       j.category,
        location:       j.location,
        status:         j.status,
        results_count:  j.results_count,
        error_message:  j.error_message,
        duration:       j.duration_seconds,
        started_at:     j.started_at,
        completed_at:   j.completed_at,
        created_at:     j.created_at
      }
    end
  end
end
