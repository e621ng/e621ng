# frozen_string_literal: true

module Admin
  module SettingsHelper
    def get_form_input_args(key)
      field = Setting.get_field(key)
      curr_value = Setting.send(key.to_sym)
      case field[:type]
      when :boolean
        {
          as: field[:type],
          input_html: {
            checked: Setting.send(:"#{key}?") ? "checked" : "",
          },
        }
      when :enum_field
        {
          as: :select,
          selected: Setting.send(key.to_sym),
          input_html: {
            value: curr_value,
          },
          collection: field[:options][:map].keys,
        }
      end
    end
  end
end
