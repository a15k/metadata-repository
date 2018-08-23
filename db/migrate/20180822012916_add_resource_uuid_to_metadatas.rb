class AddResourceUuidToMetadatas < ActiveRecord::Migration[5.2]
  def change
    add_column :metadata, :resource_uuid, :uuid

    reversible do |dir|
      dir.up do
        Metadata.update_all(
          <<-UPDATE_SQL.strip_heredoc
            "resource_uuid" = (
              SELECT "resources"."uuid"
              FROM "resources"
              WHERE "resources"."id" = "metadata"."resource_id"
            )
          UPDATE_SQL
        )
      end
    end

    change_column_null :metadata, :resource_uuid, false

    add_index :metadata, :resource_uuid
  end
end
