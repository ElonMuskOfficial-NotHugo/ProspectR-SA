source "https://rubygems.org"

gem "rails", "~> 8.0.3"
gem "sqlite3", ">= 2.1"
gem "puma", ">= 5.0"
gem "tzinfo-data", platforms: %i[ windows jruby ]
gem "bootsnap", require: false

# Pin psych to the version bundled with Ruby 3.4 (already compiled — no build needed)
gem "psych", "~> 5.2.2"

# HTTP client for scraping
gem "httparty"

# HTML parsing for scraping
gem "nokogiri"

# PDF generation
gem "prawn"
gem "prawn-table"

# CORS support so the frontend can call the API
gem "rack-cors"

# debug gem omitted — pulls in psych 5.x which needs MSYS2 libyaml headers on Windows
