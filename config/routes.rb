Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  # Serve the frontend SPA
  root to: proc { [200, { 'Content-Type' => 'text/html' }, [File.read(Rails.root.join('public', 'index.html'))]] }

  namespace :api do
    # Businesses
    get    'businesses',        to: 'businesses#index'
    get    'businesses/stats',  to: 'businesses#stats'
    get    'businesses/:id',    to: 'businesses#show'
    delete 'businesses/:id',    to: 'businesses#destroy'

    # Scraping
    get  'scrape_jobs',      to: 'scrape_jobs#index'
    post 'scrape_jobs',      to: 'scrape_jobs#create'
    post 'scrape_jobs/bulk', to: 'scrape_jobs#bulk'
    get  'scrape_jobs/:id',  to: 'scrape_jobs#show'

    # Auditing
    post 'audits',                       to: 'audit_results#create'
    post 'audits/business/:business_id', to: 'audit_results#run_single'

    # Settings
    get   'settings', to: 'settings#index'
    patch 'settings', to: 'settings#update'

    # Export
    get 'export/pdf', to: 'exports#pdf'
  end
end
