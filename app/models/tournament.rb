class Tournament < ApplicationRecord
  STATUSES = %w[created registration_open running finished cancelled].freeze

  has_many :tournament_entries, dependent: :destroy
  has_many :agents, through: :tournament_entries

  validates :name, presence: true
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :time_control, presence: true

  def registration_open?
    status == "registration_open"
  end

  def registered_count
    tournament_entries.registered.count
  end
end
