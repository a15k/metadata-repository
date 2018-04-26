class Stats < ApplicationRecord
  belongs_to :application,                      inverse_of: :stats
  belongs_to :application_user, optional: true, inverse_of: :stats
  belongs_to :resource,                         inverse_of: :stats
  belongs_to :format,                           inverse_of: :stats
  belongs_to :language,         optional: true, inverse_of: :stats

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
      SELECT
        SETWEIGHT(TO_TSVECTOR("ts_config"."regconfig", COALESCE("resources"."title", '')), 'A') ||
        SETWEIGHT(TO_TSVECTOR("ts_config"."regconfig", "resources"."content"), 'C') ||
        SETWEIGHT(TO_TSVECTOR("ts_config"."regconfig", NEW."value"), 'D')
      FROM "resources" CROSS JOIN "ts_config"
      WHERE "resources"."id" = NEW."resource_id"
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
