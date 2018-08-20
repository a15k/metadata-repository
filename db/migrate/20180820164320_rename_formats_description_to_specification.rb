class RenameFormatsDescriptionToSpecification < ActiveRecord::Migration[5.2]
  def change
    rename_column :formats, :description, :specification
  end
end
