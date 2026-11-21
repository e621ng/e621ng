# frozen_string_literal: true

module FormSearchHelper
  # needed for filled_form_fields to know which fields to look for in the params
  DEFAULT_SEARCH_FIELDS = %i[id created_at updated_at].freeze

  # ignore_for_display lists fields whose value alone does not open the form, such as an order the page also
  # lets you pick outside of it.
  def form_search(path:, always_display: false, hideable: request.path.split("/")[2] != "search", method: :get, exclude_default_fields: %i[], ignore_for_display: %i[], &) # rubocop:disable Metrics/ParameterLists
    # NOTE: dedicated search routes like /comments/search should always show
    exclude_default_fields = Array(exclude_default_fields).map(&:to_sym)
    search_params = params[:search] || {}

    filled_fields = filled_form_fields(search_params, exclude_default_fields: exclude_default_fields, &) - Array(ignore_for_display).map(&:to_sym)
    show_on_load = filled_fields.any? || always_display || !hideable
    form = simple_form_for(:search, {
      method: method,
      url: path,
      builder: SearchFormBuilder,
      search_params: search_params,
      defaults: { required: false },
      html: { class: "inline-form" },
    }) do |f|
      inputs = []
      inputs << f.input(:id, label: "ID", hide_unless_value: true) unless exclude_default_fields.include?(:id)
      inputs << f.input(:created_at, hide_unless_value: true) unless exclude_default_fields.include?(:created_at)
      inputs << f.input(:updated_at, hide_unless_value: true) unless exclude_default_fields.include?(:updated_at)
      inputs << capture { yield(f) }
      inputs << f.submit("Search")
      safe_join(inputs)
    end
    render "application/form_search", hideable: hideable, show_on_load: show_on_load, form: form
  end

  # When the simple_form has f.input :name and search[name]=test [:name] will be returned
  # Some search params aren't exposed in the ui, but have links. In that case it
  # isn't expected to have the form be open, since no values are set.
  def filled_form_fields(search_params, exclude_default_fields: [], &)
    form_field_collector = FormFieldCollector.new
    capture { yield(form_field_collector) }
    available_fields = DEFAULT_SEARCH_FIELDS - exclude_default_fields + form_field_collector.fields
    available_fields & search_params.keys.map(&:to_sym)
  end
end
