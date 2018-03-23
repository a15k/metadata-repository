class CreateResources < ActiveRecord::Migration[5.1]
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
      t.citext     :type,             null: false
      t.text       :title
      t.text       :content,          null: false
      t.tsvector   :tsvector,         null: false, index: { using: :gin }

      t.timestamps
    end

    add_index :resources, [ :uuid, :application_id ], unique: true
    add_index :resources, [ :uri,  :application_id ], unique: true
  end
end
