class CreateApplications < ActiveRecord::Migration[5.2]
  def change
    enable_extension :citext

    create_table :applications do |t|
      t.uuid   :uuid,  null: false, index: { unique: true }
      t.citext :name,  null: false
      t.string :token, null: false, index: { unique: true }

      t.timestamps
    end
  end
end
