class ApplicationUser < ApplicationRecord
  has_many :resources,     inverse_of: :application_user
  has_many :metadatas,     inverse_of: :application_user
  has_many :stats,         inverse_of: :application_user

  belongs_to :application, inverse_of: :application_users

  validates :uuid, presence: true, uniqueness: { scope: :application_id }

  def application_uuid
    application.uuid
  end
end
