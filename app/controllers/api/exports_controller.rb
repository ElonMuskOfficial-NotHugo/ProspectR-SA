module Api
  class ExportsController < ApplicationController
    def pdf
      businesses = Business.includes(:audit_result).all

      businesses = businesses.by_city(params[:city])         if params[:city].present?
      businesses = businesses.by_province(params[:province]) if params[:province].present?
      businesses = businesses.by_source(params[:source])     if params[:source].present?

      if params[:min_score].present?
        businesses = businesses.joins(:audit_result).where("audit_results.score >= ?", params[:min_score].to_i)
      end

      if params[:quality].present?
        case params[:quality]
        when 'no_website' then businesses = businesses.no_website
        when 'high'   then businesses = businesses.joins(:audit_result).where("audit_results.score >= 70")
        when 'medium' then businesses = businesses.joins(:audit_result).where("audit_results.score >= 40 AND audit_results.score < 70")
        end
      end

      if params[:website].present?
        case params[:website]
        when 'has'  then businesses = businesses.has_website
        when 'none' then businesses = businesses.no_website
        end
      end

      businesses = businesses.recently_added.limit(500)

      filters = {
        city:      params[:city],
        province:  params[:province],
        source:    params[:source],
        quality:   params[:quality],
        website:   params[:website],
        min_score: params[:min_score]
      }.compact

      pdf_data = PdfExporter.new(businesses.to_a, filters: filters).generate

      send_data pdf_data,
                filename:    "prospectr_sa_#{Date.today}.pdf",
                type:        'application/pdf',
                disposition: 'attachment'
    rescue => e
      Rails.logger.error "[ExportsController] PDF error: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
      render json: { error: "PDF generation failed: #{e.message}" }, status: :internal_server_error
    end
  end
end
