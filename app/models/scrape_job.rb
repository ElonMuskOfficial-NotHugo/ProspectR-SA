class ScrapeJob < ApplicationRecord
  STATUSES   = %w[pending running completed failed].freeze
  SOURCES    = %w[yellow_pages brabys google_places cipc].freeze

  validates :source, inclusion: { in: SOURCES }
  validates :status, inclusion: { in: STATUSES }

  scope :recent,    -> { order(created_at: :desc) }
  scope :running,   -> { where(status: 'running') }
  scope :completed, -> { where(status: 'completed') }
  scope :failed,    -> { where(status: 'failed') }

  def duration_seconds
    return nil unless started_at && completed_at
    (completed_at - started_at).round
  end

  def mark_running!
    update!(status: 'running', started_at: Time.current)
  end

  def mark_completed!(count)
    update!(status: 'completed', completed_at: Time.current, results_count: count)
  end

  def mark_failed!(msg)
    update!(status: 'failed', completed_at: Time.current, error_message: msg)
  end
end
