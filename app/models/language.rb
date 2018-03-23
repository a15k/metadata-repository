class Language < ApplicationRecord
  has_many :resources, inverse_of: :language

  validates :name, presence: true, uniqueness: true
end
