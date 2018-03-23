class CreateFormats < ActiveRecord::Migration[5.1]
  def change
    enable_extension :citext

    create_table :formats do |t|
      t.citext :name,        null: false, index: { unique: true }
      t.text   :description

      t.timestamps
    end
  end
end
