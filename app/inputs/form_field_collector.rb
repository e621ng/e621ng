# Captures all the input names used in a form block
class FormFieldCollector
  attr_reader :fields

  def initialize
    @fields = []
  end

  def input(input_name, *)
    @fields.push input_name
  end

  # Swallow the rest
  def method_missing(*)
  end
end
