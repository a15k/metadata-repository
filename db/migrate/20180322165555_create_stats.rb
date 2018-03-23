class CreateStats < ActiveRecord::Migration[5.1]
  def change
    create_table :stats do |t|
      t.references :application,      null: false,
                                      foreign_key: { on_update: :cascade, on_delete: :cascade }
      t.references :application_user, foreign_key: { on_update: :cascade, on_delete: :nullify }
      t.references :resource,         null: false,
                                      foreign_key: { on_update: :cascade, on_delete: :cascade }
      t.references :format,           null: false,
                                      foreign_key: { on_update: :cascade, on_delete: :cascade }
      t.uuid       :uuid,             null: false
      t.jsonb      :value,            null: false, index: { using: :gin }

      t.timestamps
    end

    add_index :stats, [ :uuid, :application_id ], unique: true
    add_index :stats, 'value jsonb_path_ops', using: :gin
  end
end
