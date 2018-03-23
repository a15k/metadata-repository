class ApplicationUser < ApplicationRecord
  has_many :resources,     inverse_of: :application_users
  has_many :metadatas,     inverse_of: :application_users
  has_many :stats,         inverse_of: :application_users

  belongs_to :application, inverse_of: :application_users

  validates :uuid, presence: true, uniqueness: true
end
