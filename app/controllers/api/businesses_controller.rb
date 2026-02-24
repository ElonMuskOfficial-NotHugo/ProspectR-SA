module Api
  class BusinessesController < ApplicationController
    def index
      businesses = Business.includes(:audit_result).all

      if params[:search].present?
        term = "%#{params[:search].gsub('%','').gsub('_','\_')}%"
        businesses = businesses.where(
          "name LIKE :q OR city LIKE :q OR category LIKE :q OR phone LIKE :q OR address LIKE :q",
          q: term
        )
      end

      businesses = businesses.by_city(params[:city])         if params[:city].present?
      businesses = businesses.by_province(params[:province]) if params[:province].present?
      businesses = businesses.by_source(params[:source])     if params[:source].present?
      businesses = businesses.where("category LIKE ?", "%#{params[:category]}%") if params[:category].present?

      if params[:min_score].present?
        businesses = businesses.joins(:audit_result).where("audit_results.score >= ?", params[:min_score].to_i)
      end

      if params[:quality].present?
        case params[:quality]
        when 'no_website' then businesses = businesses.no_website
        when 'high'   then businesses = businesses.joins(:audit_result).where("audit_results.score >= 70")
        when 'medium' then businesses = businesses.joins(:audit_result).where("audit_results.score >= 40 AND audit_results.score < 70")
        when 'low'    then businesses = businesses.joins(:audit_result).where("audit_results.score < 40")
        end
      end

      businesses = businesses.recently_added

      total = businesses.count
      businesses = businesses.offset(params[:offset].to_i).limit(params[:limit] || 50)

      render json: {
        total:      total,
        businesses: businesses.map { |b| serialize(b) }
      }
    end

    def show
      business = Business.includes(:audit_result).find(params[:id])
      render json: serialize(business)
    rescue ActiveRecord::RecordNotFound
      render json: { error: 'Not found' }, status: :not_found
    end

    def destroy
      Business.find(params[:id]).destroy
      render json: { success: true }
    rescue ActiveRecord::RecordNotFound
      render json: { error: 'Not found' }, status: :not_found
    end

    def stats
      render json: {
        total:       Business.count,
        no_website:  Business.no_website.count,
        needs_audit: Business.needs_audit.count,
        audited:     AuditResult.count,
        high_prospects:   Business.joins(:audit_result).where("audit_results.score >= 70").count,
        medium_prospects: Business.joins(:audit_result).where("audit_results.score >= 40 AND audit_results.score < 70").count,
        sources:     Business.group(:source).count,
        cities:      Business.group(:city).count.sort_by { |_, v| -v }.first(10).to_h
      }
    end

    private

    def serialize(b)
      audit = b.audit_result
      {
        id:              b.id,
        name:            b.name,
        category:        b.category,
        phone:           b.phone,
        email:           b.email,
        address:         b.address,
        city:            b.city,
        province:        b.province,
        website_url:     b.website_url,
        source:          b.source,
        needs_audit:     b.needs_audit,
        prospect_quality: b.prospect_quality,
        scraped_at:      b.scraped_at,
        created_at:      b.created_at,
        audit: audit ? {
          id:                audit.id,
          score:             audit.score,
          has_website:       audit.has_website,
          has_ssl:           audit.has_ssl,
          is_mobile_friendly: audit.is_mobile_friendly,
          cms_detected:      audit.cms_detected,
          load_time_ms:      audit.load_time_ms,
          copyright_year:    audit.copyright_year,
          issues:            (JSON.parse(audit.issues || '[]') rescue []),
          audited_at:        audit.audited_at
        } : nil
      }
    end
  end
end
