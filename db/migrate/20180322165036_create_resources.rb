class CreateResources < ActiveRecord::Migration[5.1]
  def change
    create_table :resources do |t|
      t.references :application,      null: false, foreign_key: true
      t.references :application_user, foreign_key: true
      t.references :format,           null: false, foreign_key: true
      t.references :language,         foreign_key: true
      t.uuid       :uuid,             null: false
      t.string     :uri,              null: false
      t.citext     :type,             null: false
      t.text       :content,          null: false
      t.tsvector   :tsvector,         null: false, index: { using: :gin }

      t.timestamps
    end

    add_index :resources, [ :uuid, :application_id ], unique: true
    add_index :resources, [ :uri,  :application_id ], unique: true
  end
end
