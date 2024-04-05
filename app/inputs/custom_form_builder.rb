# frozen_string_literal: true

class CustomFormBuilder < SimpleForm::FormBuilder
  def input(attribute_name, options = {}, &)
    options = insert_autocomplete(options)
    super
  end

  include FormBuilderCommon
end
