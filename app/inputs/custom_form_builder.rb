class CustomFormBuilder < SimpleForm::FormBuilder
  def input(attribute_name, options = {}, &)
    options = insert_autocomplete(options)
    super
  end

  def button_select(attribute_name, values, **args)
    html = collection_radio_buttons(attribute_name, values, :first, :last)
    label = args[:label] || attribute_name.to_s.titleize
    %(<div class="collection-radio-buttons input">
      <label>#{label}</label>
      #{html}
    </div>).html_safe
  end

  include FormBuilderCommon
end
