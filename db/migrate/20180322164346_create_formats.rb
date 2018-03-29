class CreateFormats < ActiveRecord::Migration[5.1]
  def change
    create_table :formats do |t|
      t.citext :name,        null: false, index: { unique: true }
      t.text   :description

      t.timestamps
    end
  end
end
