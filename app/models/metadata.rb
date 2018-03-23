class Metadata < ApplicationRecord
  belongs_to :application,                      inverse_of: :metadatas
  belongs_to :application_user, optional: true, inverse_of: :metadatas
  belongs_to :resource,                         inverse_of: :metadatas
  belongs_to :format,                           inverse_of: :metadatas

  validates :uuid,  presence: true, uniqueness: { scope: :application_id }
  validates :value, presence: true
end
