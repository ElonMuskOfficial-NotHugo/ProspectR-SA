module Api
  class AuditResultsController < ApplicationController
    def create
      business_ids = Array(params[:business_ids])

      if business_ids.present?
        business_ids.each { |id| AuditWorkerJob.perform_later(id.to_i) }
        render json: { message: "Queued #{business_ids.size} audits" }
      else
        count = Business.needs_audit.count
        AuditWorkerJob.enqueue_pending(limit: params[:limit]&.to_i || 50)
        render json: { message: "Queued up to #{count} pending audits" }
      end
    end

    def run_single
      business = Business.find(params[:business_id])
      result   = WebsiteAuditor.new(business).audit
      if result
        render json: {
          score:             result.score,
          has_website:       result.has_website,
          has_ssl:           result.has_ssl,
          is_mobile_friendly: result.is_mobile_friendly,
          cms_detected:      result.cms_detected,
          load_time_ms:      result.load_time_ms,
          copyright_year:    result.copyright_year,
          issues:            (JSON.parse(result.issues || '[]') rescue []),
          audited_at:        result.audited_at
        }
      else
        render json: { error: 'Audit failed' }, status: :unprocessable_entity
      end
    rescue ActiveRecord::RecordNotFound
      render json: { error: 'Business not found' }, status: :not_found
    end
  end
end
