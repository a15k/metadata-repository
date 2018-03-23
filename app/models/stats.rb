class Stats < ApplicationRecord
  belongs_to :application,      inverse_of: :stats
  belongs_to :application_user, optional: true, inverse_of: :stats
  belongs_to :resource,         inverse_of: :stats
  belongs_to :format,           inverse_of: :stats

  validates :uuid,  presence: true, uniqueness: true
  validates :value, presence: true
end
