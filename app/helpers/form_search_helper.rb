module FormSearchHelper
  def form_search(path:, always_display: false, &block)
    # dedicated search routes like /comments/search should always show
    hideable = request.path.split("/")[2] != "search"
    show_on_load = filled_form_fields(block).any? || always_display || !hideable
    render "application/form_search", path: path, hideable: hideable, show_on_load: show_on_load, block: block
  end

  # When the simple_form has f.input :name and search[name]=test [:name] will be returned
  # Some search params aren't exposed in the ui, but have links. In that case it
  # isn't expected to have the form be open, since no values are set.
  def filled_form_fields(block)
    form_field_collector = FormFieldCollector.new
    capture { block.call(form_field_collector) }
    form_field_collector.fields & params[:search].keys.map(&:to_sym)
  end
end
