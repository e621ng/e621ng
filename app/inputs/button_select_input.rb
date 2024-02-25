# frozen_string_literal: true

# This behaves just like the inherited input, but adds
# a css class for custom styling. Nothing more, nothing less.
class ButtonSelectInput < SimpleForm::Inputs::CollectionRadioButtonsInput
  def input_type
    "radio_buttons"
  end

  def input_class
    "collection-radio-buttons"
  end
end
