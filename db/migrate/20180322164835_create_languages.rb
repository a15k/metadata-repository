class CreateLanguages < ActiveRecord::Migration[5.2]
  def change
    create_table :languages do |t|
      t.citext :name, null: false, index: { unique: true }

      t.timestamps
    end
  end
end
