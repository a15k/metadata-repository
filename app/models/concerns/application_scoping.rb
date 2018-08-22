module ApplicationScoping
  extend ActiveSupport::Concern

  included { attr_accessor :scoped_to_application }

  class_methods do
    def scoped_has_many(relation, options)
      has_many(relation, options)
      unscoped_name = "unscoped_#{relation}".to_sym
      has_many(unscoped_name, class_name: relation.to_s.classify,
                              primary_key: :uuid, foreign_key: :resource_uuid)

      define_method("scoped_#{relation}") do
        scoped_to_application ||= application

        send(unscoped_name).sort_by(&:id).sort_by do |record|
          record.application == scoped_to_application
        end.uniq(&:uuid)
      end
    end

    def scoped_belongs_to(relation, options)
      belongs_to(relation, options)
      unscoped_name = "unscoped_#{relation.to_s.pluralize}".to_sym
      has_many(unscoped_name, class_name: relation.to_s.classify,
                              primary_key: :resource_uuid, foreign_key: :uuid)

      define_method("scoped_#{relation}") do
        scoped_to_application ||= application

        records = send(unscoped_name).to_a
        records.find { |record| record.application == scoped_to_application } ||
        records.min_by(&:id)
      end
    end
  end
end
