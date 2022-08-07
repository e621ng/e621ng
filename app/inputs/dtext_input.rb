class DtextInput < SimpleForm::Inputs::TextInput
  def input(wrapper_options = nil)
    input_html_options[:cols] = "80"
    input_html_options[:rows] = "10"
    input_html_options["data-limit"] ||= @options[:limit]
    input_html_options["data-initialized"] = false

    merged_input_options = merge_wrapper_options(input_html_options, wrapper_options)

    link = ApplicationController.helpers.link_to "DText", Rails.application.routes.url_helpers.help_page_path(id: "dtext"), target: "_blank", tabindex: "-1"
    %(
      #{super(merged_input_options)}
      <span class="hint">All text is formatted using #{link}</span>
    ).html_safe
  end
end
