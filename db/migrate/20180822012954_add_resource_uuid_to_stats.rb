class AddResourceUuidToStats < ActiveRecord::Migration[5.2]
  def change
    add_column :stats, :resource_uuid, :uuid

    reversible do |dir|
      dir.up do
        Stats.update_all(
          <<-UPDATE_SQL.strip_heredoc
            "resource_uuid" = (
              SELECT "resources"."uuid"
              FROM "resources"
              WHERE "resources"."id" = "stats"."resource_id"
            )
          UPDATE_SQL
        )
      end
    end

    change_column_null :stats, :resource_uuid, false

    add_index :stats, :resource_uuid
  end
end
