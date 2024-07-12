# frozen_string_literal: true

module FormBuilderCommon
  def insert_autocomplete(options)
    options[:input_html] ||= {}
    options[:input_html][:data] = {}
    options[:input_html][:data][:autocomplete] = options[:autocomplete] if options[:autocomplete]
    options
  end
end
