class CreateApplicationUsers < ActiveRecord::Migration[5.1]
  def change
    create_table :application_users do |t|
      t.uuid       :uuid,        null: false
      t.references :application, null: false, foreign_key: true

      t.timestamps
    end

    add_index :application_users, [ :uuid, :application_id ], unique: true
  end
end
