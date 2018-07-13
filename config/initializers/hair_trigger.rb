# Monkeypatch for Rails 5.2 compatibility
module HairTrigger
  class << self
    def migrator
      ActiveRecord::MigrationContext.new(migration_path)
    end

    def generate_migration(silent = false)
      begin
        canonical_triggers = current_triggers
      rescue
        $stderr.puts $!
        exit 1
      end

      migrations = current_migrations
      migration_names = migrations.map(&:first)
      existing_triggers = migrations.map(&:last)

      up_drop_triggers = []
      up_create_triggers = []
      down_drop_triggers = []
      down_create_triggers = []

      # see which triggers need to be dropped
      existing_triggers.each do |existing|
        next if canonical_triggers.any?{ |t| t.prepared_name == existing.prepared_name }
        up_drop_triggers.concat existing.drop_triggers
        down_create_triggers << existing
      end

      # see which triggers need to be added/replaced
      (canonical_triggers - existing_triggers).each do |new_trigger|
        up_create_triggers << new_trigger
        down_drop_triggers.concat new_trigger.drop_triggers
        if existing = existing_triggers.detect{ |t| t.prepared_name == new_trigger.prepared_name }
          # it's not sufficient to rely on the new trigger to replace the old
          # one, since we could be dealing with trigger groups and the name
          # alone isn't sufficient to know which component triggers to remove
          up_drop_triggers.concat existing.drop_triggers
          down_create_triggers << existing
        end
      end

      return if up_drop_triggers.empty? && up_create_triggers.empty?

      migration_name = infer_migration_name(migration_names, up_create_triggers, up_drop_triggers)
      migration_version = infer_migration_version(migration_name)
      file_name = migration_path + '/' + migration_version + "_" + migration_name.underscore + ".rb"
      FileUtils.mkdir_p migration_path
      prefix = ActiveRecord::VERSION::STRING < "3.1." ? "self." : ""
      File.open(file_name, "w"){ |f| f.write <<-MIGRATION }
# This migration was auto-generated via `rake db:generate_trigger_migration'.
# While you can edit this file, any changes you make to the definitions here
# will be undone by the next auto-generated trigger migration.
class #{migration_name} < ActiveRecord::Migration[#{Rails::VERSION::MAJOR}.#{Rails::VERSION::MINOR}]
  def #{prefix}up
    #{(up_drop_triggers + up_create_triggers).map{ |t| t.to_ruby('    ') }.join("\n\n").lstrip}
  end
  def #{prefix}down
    #{(down_drop_triggers + down_create_triggers).map{ |t| t.to_ruby('    ') }.join("\n\n").lstrip}
  end
end
      MIGRATION
      file_name
    end
  end
end
