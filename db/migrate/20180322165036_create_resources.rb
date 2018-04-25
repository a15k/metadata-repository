class CreateResources < ActiveRecord::Migration[5.2]
  def change
    create_table :resources do |t|
      t.references :application,      null: false,
                                      foreign_key: { on_update: :cascade, on_delete: :cascade }
      t.references :application_user, foreign_key: { on_update: :cascade, on_delete: :nullify }
      t.references :format,           null: false,
                                      foreign_key: { on_update: :cascade, on_delete: :cascade }
      t.references :language,         foreign_key: { on_update: :cascade, on_delete: :nullify }
      t.uuid       :uuid,             null: false
      t.string     :uri,              null: false
      t.citext     :resource_type,    null: false, index: true
      t.text       :title,                         index: true
      t.text       :content,          null: false
      t.tsvector   :tsvector,         null: false, index: { using: :gin }

      t.timestamps
    end

    add_index :resources, [ :uuid, :application_id ], unique: true
    add_index :resources, [ :uri,  :application_id ], unique: true
    add_index :resources, :created_at
    add_index :resources, :updated_at
  end
end
