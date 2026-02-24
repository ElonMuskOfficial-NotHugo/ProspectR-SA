class AuditWorkerJob < ApplicationJob
  queue_as :default

  def perform(business_id)
    business = Business.find(business_id)
    WebsiteAuditor.new(business).audit
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.warn "[AuditJob] Business #{business_id} not found: #{e.message}"
  end

  def self.enqueue_pending(limit: 50)
    Business.needs_audit.limit(limit).each do |business|
      perform_later(business.id)
    end
  end
end
