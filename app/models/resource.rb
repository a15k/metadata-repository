class Resource < ApplicationRecord
  self.inheritance_column = nil

  has_many :metadatas,          dependent: :destroy, inverse_of: :resource
  has_many :stats,              dependent: :destroy, inverse_of: :resource

  belongs_to :application,      inverse_of: :resource
  belongs_to :application_user, optional: true, inverse_of: :resource
  belongs_to :format,           inverse_of: :resource
  belongs_to :language,         optional: true, inverse_of: :resource

  before_validation :set_content

  validates :uuid, :uri,     presence: true, uniqueness: true
  validates :type, :content, presence: true

  def set_content
    self.content ||= FaradayWithRedirects.get uri
  end
end
