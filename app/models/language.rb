class Language < ApplicationRecord
  has_many :resources, inverse_of: :language
  has_many :metadatas, inverse_of: :language
  has_many :stats,     inverse_of: :language

  validates :name, presence: true, uniqueness: true
end
