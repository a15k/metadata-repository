# This migration was auto-generated via `rake db:generate_trigger_migration'.
# While you can edit this file, any changes you make to the definitions here
# will be undone by the next auto-generated trigger migration.

class CreateTriggersResourcesInsertOrResourcesUpdate < ActiveRecord::Migration[5.1]
  def up
    create_trigger("resources_before_insert_row_tr", :generated => true, :compatibility => 1).
        on("resources").
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
  SELECT SETWEIGHT(TO_TSVECTOR("ts_config"."regconfig", COALESCE(NEW."title", '')), 'A') ||
         SETWEIGHT(TO_TSVECTOR("ts_config"."regconfig", NEW."content"), 'D')
  FROM "ts_config"
);
      SQL_ACTIONS
    end

    create_trigger("resources_before_update_of_title_content_row_tr", :generated => true, :compatibility => 1).
        on("resources").
        before(:update).
        of(:title, :content) do
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
  SELECT SETWEIGHT(TO_TSVECTOR("ts_config"."regconfig", COALESCE(NEW."title", '')), 'A') ||
         SETWEIGHT(TO_TSVECTOR("ts_config"."regconfig", NEW."content"), 'D')
  FROM "ts_config"
);
      SQL_ACTIONS
    end
  end

  def down
    drop_trigger("resources_before_insert_row_tr", "resources", :generated => true)

    drop_trigger("resources_before_update_of_title_content_row_tr", "resources", :generated => true)
  end
end
