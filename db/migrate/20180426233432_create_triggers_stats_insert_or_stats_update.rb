# This migration was auto-generated via `rake db:generate_trigger_migration'.
# While you can edit this file, any changes you make to the definitions here
# will be undone by the next auto-generated trigger migration.
class CreateTriggersStatsInsertOrStatsUpdate < ActiveRecord::Migration[5.2]
  def up
    create_trigger("stats_before_insert_row_tr", :generated => true, :compatibility => 1).
        on("stats").
        before(:insert) do
      <<-SQL_ACTIONS
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
);
      SQL_ACTIONS
    end

    create_trigger("stats_before_update_of_value_row_tr", :generated => true, :compatibility => 1).
        on("stats").
        before(:update).
        of(:value) do
      <<-SQL_ACTIONS
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
);
      SQL_ACTIONS
    end
  end
  def down
    drop_trigger("stats_before_insert_row_tr", "stats", :generated => true)

    drop_trigger("stats_before_update_of_value_row_tr", "stats", :generated => true)
  end
end
