# frozen_string_literal: true

module FormSearchHelper
  def form_search(path:, always_display: false, hideable: request.path.split("/")[2] != "search", method: :get, &)
    # dedicated search routes like /comments/search should always show
    search_params = params[:search] || {}
    show_on_load = filled_form_fields(search_params, &).any? || always_display || !hideable
    form = simple_form_for(:search, {
      method: method,
      url: path,
      builder: SearchFormBuilder,
      search_params: search_params,
      defaults: { required: false },
      html: { class: "inline-form" },
    }) do |f|
      id_input = f.input(:id, label: "ID", hide_unless_value: true)
      created_at_input = f.input(:created_at, hide_unless_value: true)
      updated_at_input = f.input(:updated_at, hide_unless_value: true)
      id_input + created_at_input + updated_at_input + capture { yield(f) } + f.submit("Search")
    end
    render "application/form_search", hideable: hideable, show_on_load: show_on_load, form: form
  end

  # When the simple_form has f.input :name and search[name]=test [:name] will be returned
  # Some search params aren't exposed in the ui, but have links. In that case it
  # isn't expected to have the form be open, since no values are set.
  def filled_form_fields(search_params, &)
    form_field_collector = FormFieldCollector.new
    capture { yield(form_field_collector) }
    available_fields = %i[id created_at updated_at] + form_field_collector.fields
    available_fields & search_params.keys.map(&:to_sym)
  end
end
