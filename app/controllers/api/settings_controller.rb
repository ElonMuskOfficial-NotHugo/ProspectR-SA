module Api
  class SettingsController < ApplicationController
    ALLOWED_KEYS = %w[
      google_places_api_key
      default_province
      default_city
      default_category
      enabled_sources
      audit_concurrency
    ].freeze

    def index
      settings = Setting.where(key: ALLOWED_KEYS).pluck(:key, :value).to_h
      # Fill in defaults for missing keys
      defaults = {
        'default_province'   => 'Western Cape',
        'default_city'       => 'Cape Town',
        'default_category'   => 'restaurant',
        'enabled_sources'    => 'yellow_pages,brabys',
        'audit_concurrency'  => '5',
        'google_places_api_key' => ''
      }
      render json: defaults.merge(settings)
    end

    def update
      params.permit!.to_h.slice(*ALLOWED_KEYS).each do |key, value|
        Setting.set(key, value)
      end
      render json: { success: true }
    end
  end
end
