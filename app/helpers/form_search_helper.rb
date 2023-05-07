module FormSearchHelper
  def form_search(path:, always_display: false, &)
    # dedicated search routes like /comments/search should always show
    hideable = request.path.split("/")[2] != "search"
    show_on_load = filled_form_fields(&).any? || always_display || !hideable
    form = simple_form_for(:search, {
      method: :get,
      url: path,
      builder: SearchFormBuilder,
      search_params: params[:search],
      defaults: { required: false },
      html: { class: "inline-form" },
    }) do |f|
      capture { yield(f) } + f.submit("Search")
    end
    render "application/form_search", hideable: hideable, show_on_load: show_on_load, form: form
  end

  # When the simple_form has f.input :name and search[name]=test [:name] will be returned
  # Some search params aren't exposed in the ui, but have links. In that case it
  # isn't expected to have the form be open, since no values are set.
  def filled_form_fields(&)
    form_field_collector = FormFieldCollector.new
    capture { yield(form_field_collector) }
    form_field_collector.fields & params[:search].keys.map(&:to_sym)
  end
end
