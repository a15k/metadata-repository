class Format < ApplicationRecord
  has_many :resources, dependent: :destroy, inverse_of: :format
  has_many :metadatas, dependent: :destroy, inverse_of: :format
  has_many :stats,     dependent: :destroy, inverse_of: :format

  validates :name, presence: true, uniqueness: true
end
