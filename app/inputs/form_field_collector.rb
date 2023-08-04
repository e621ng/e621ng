# Captures all the input names used in a form block
class FormFieldCollector
  attr_reader :fields

  def initialize
    @fields = []
  end

  def input(input_name, **)
    @fields.push(input_name)
  end

  def user(input_prefix, **)
    if input_prefix.is_a?(Array)
      @fields.push(*input_prefix)
    else
      @fields.push(:"#{input_prefix}_id", :"#{input_prefix}_name")
    end
  end

  # Swallow the rest
  def method_missing(*)
  end
end
