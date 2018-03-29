class Application < ApplicationRecord
  has_many :application_users, dependent: :destroy, inverse_of: :application
  has_many :resources,         dependent: :destroy, inverse_of: :application
  has_many :metadatas,         dependent: :destroy, inverse_of: :application
  has_many :stats,             dependent: :destroy, inverse_of: :application

  validates :uuid, presence: true, uniqueness: true
  validates :name, presence: true
end
