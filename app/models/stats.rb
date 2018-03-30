class Stats < ApplicationRecord
  belongs_to :application,                      inverse_of: :stats
  belongs_to :application_user, optional: true, inverse_of: :stats
  belongs_to :resource,                         inverse_of: :stats
  belongs_to :format,                           inverse_of: :stats

  validates :uuid,  presence: true, uniqueness: { scope: :application_id }
  validates :value, presence: true

  def application_uuid
    application.uuid
  end

  def application_user_uuid
    application_user&.uuid
  end

  def resource_uuid
    resource.uuid
  end

  def format_name
    format.name
  end
end
