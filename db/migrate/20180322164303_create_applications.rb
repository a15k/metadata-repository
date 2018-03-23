class CreateApplications < ActiveRecord::Migration[5.1]
  def change
    create_table :applications do |t|
      t.uuid :uuid, null: false, index: { unique: true }

      t.timestamps
    end
  end
end
