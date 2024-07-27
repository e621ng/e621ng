# frozen_string_literal: true

class BooleanInput < SimpleForm::Inputs::BooleanInput
  # Fix styling because the input appears before the label
  def label_input(wrapper_options = nil)
    # since boolean_style = :inline, the other mode doesn't need to be supported
    if options[:label] == false || inline_label?
      input(wrapper_options)
    else
      label(wrapper_options) + input(wrapper_options)
    end
  end
end
