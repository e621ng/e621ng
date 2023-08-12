class DtextInput < SimpleForm::Inputs::TextInput
  def input(wrapper_options = nil)
    input_html_options[:cols] = "80"
    input_html_options[:rows] = "10"
    if object
      input_html_options[:id] ||= "#{object.model_name.param_key}_#{attribute_name}_for_#{object.id}"
    end

    merged_input_options = merge_wrapper_options(input_html_options, wrapper_options)
    @builder.template.render("dtext_input", textarea: super(merged_input_options), limit: @options[:limit])
  end

  def input_html_classes
    super.push("dtext-formatter-input")
  end
end
