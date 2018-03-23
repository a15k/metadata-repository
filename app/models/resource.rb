class Resource < ApplicationRecord
  self.inheritance_column = nil

  has_many :metadatas,          dependent: :destroy, inverse_of: :resource
  has_many :stats,              dependent: :destroy, inverse_of: :resource

  belongs_to :application,                           inverse_of: :resources
  belongs_to :application_user, optional: true,      inverse_of: :resources
  belongs_to :format,                                inverse_of: :resources
  belongs_to :language,         optional: true,      inverse_of: :resources

  before_validation :set_content

  validates :uuid, :uri,     presence: true, uniqueness: { scope: :application_id }
  validates :type, :content, presence: true

  def set_content
    self.content ||= FaradayWithRedirects.get uri
  end
end
