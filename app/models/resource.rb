class Resource < ApplicationRecord
  TSVECTOR_UPDATE_SQL = <<-TSVECTOR_UPDATE_SQL.strip_heredoc
    NEW."tsvector" = (
      WITH "ts_config" AS (
        SELECT COALESCE(
          (
            SELECT "pg_ts_config"."cfgname"
            FROM "pg_ts_config"
              INNER JOIN "languages"
                ON "pg_ts_config"."cfgname" = "languages"."name"
            WHERE "languages"."id" = NEW."language_id"
          )::regconfig, 'simple'
        ) AS "regconfig"
      )
      SELECT SETWEIGHT(TO_TSVECTOR("ts_config"."regconfig", COALESCE(NEW."title", '')), 'A') ||
             SETWEIGHT(TO_TSVECTOR("ts_config"."regconfig", NEW."content"), 'D')
      FROM "ts_config"
    )
  TSVECTOR_UPDATE_SQL

  trigger.before(:insert)                      { TSVECTOR_UPDATE_SQL }
  trigger.before(:update).of(:title, :content) { TSVECTOR_UPDATE_SQL }

  has_many :metadatas,          dependent: :destroy, inverse_of: :resource
  has_many :stats,              dependent: :destroy, inverse_of: :resource

  belongs_to :application,                           inverse_of: :resources
  belongs_to :application_user, optional: true,      inverse_of: :resources
  belongs_to :format,                                inverse_of: :resources
  belongs_to :language,         optional: true,      inverse_of: :resources

  before_validation :set_content

  validates :uuid, :uri,              presence: true, uniqueness: { scope: :application_id }
  validates :resource_type, :content, presence: true

  def set_content
    self.content ||= FaradayWithRedirects.get uri
  end

  def application_uuid
    application.uuid
  end

  def application_user_uuid
    application_user&.uuid
  end

  def format_name
    format.name
  end

  def language_name
    language&.name
  end
end
