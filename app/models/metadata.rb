class Metadata < ApplicationRecord
  belongs_to :application,                      inverse_of: :metadatas
  belongs_to :application_user, optional: true, inverse_of: :metadatas
  belongs_to :resource,                         inverse_of: :metadatas
  belongs_to :format,                           inverse_of: :metadatas
  belongs_to :language,         optional: true, inverse_of: :metadatas

  validates :uuid,  presence: true, uniqueness: { scope: :application_id }
  validates :value, presence: true

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
      SELECT SETWEIGHT(TO_TSVECTOR("ts_config"."regconfig", NEW."value"), 'B')
      FROM "ts_config"
    )
  TSVECTOR_UPDATE_SQL

  trigger.before(:insert)            { TSVECTOR_UPDATE_SQL }
  trigger.before(:update).of(:value) { TSVECTOR_UPDATE_SQL }

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

  def language_name
    language&.name
  end
end
