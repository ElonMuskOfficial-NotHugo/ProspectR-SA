class CreateScrapeJobs < ActiveRecord::Migration[8.0]
  def change
    create_table :scrape_jobs do |t|
      t.string   :source,        null: false
      t.string   :category
      t.string   :location
      t.string   :status,        null: false, default: 'pending'
      t.integer  :results_count, null: false, default: 0
      t.text     :error_message
      t.datetime :started_at
      t.datetime :completed_at

      t.timestamps
    end

    add_index :scrape_jobs, :status
    add_index :scrape_jobs, :source
    add_index :scrape_jobs, :created_at
  end
end
