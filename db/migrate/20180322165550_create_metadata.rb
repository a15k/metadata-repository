class CreateMetadata < ActiveRecord::Migration[5.1]
  def change
    create_table :metadata do |t|
      t.references :application,      null: false, foreign_key: true
      t.references :application_user, foreign_key: true
      t.references :resource,         null: false, foreign_key: true
      t.references :format,           null: false, foreign_key: true
      t.uuid       :uuid,             null: false
      t.jsonb      :value,            null: false, index: { using: :gin }

      t.timestamps
    end

    add_index :metadata, [ :uuid, :application_id ], unique: true
    add_index :metadata, 'value jsonb_path_ops', using: :gin
  end
end
