class SearchFormBuilder < SimpleForm::FormBuilder
  def input(attribute_name, options = {}, &)
    value = value_for_attribute(attribute_name, options)
    return if value.nil? && options[:hide_unless_value]
    options = insert_autocomplete(options)
    options = insert_value(value, options)
    super
  end

  private

  def insert_value(value, options)
    return options if value.nil?

    if options[:collection]
      options[:selected] = value
    elsif options[:as]&.to_sym == :boolean
      options[:input_html][:checked] = true if value.truthy?
    else
      options[:input_html][:value] = value
    end
    options
  end

  def value_for_attribute(attribute_name, options)
    @options[:search_params][attribute_name] || options[:default]&.to_s
  end

  include FormBuilderCommon
end
