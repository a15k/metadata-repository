class SecurityTransgression < StandardError
  attr_reader :record

  def initialize(record)
    @record = record
  end

  def record_class
    record.is_a?(Class) ? record.name : record.class.name
  end

  def message
    "You are not allowed to modify the given #{record_class}."
  end
end
