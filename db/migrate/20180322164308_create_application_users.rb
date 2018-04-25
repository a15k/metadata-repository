class CreateApplicationUsers < ActiveRecord::Migration[5.2]
  def change
    create_table :application_users do |t|
      t.uuid       :uuid,        null: false
      t.references :application, null: false,
                                 foreign_key: { on_update: :cascade, on_delete: :cascade }

      t.timestamps
    end

    add_index :application_users, [ :uuid, :application_id ], unique: true
  end
end
