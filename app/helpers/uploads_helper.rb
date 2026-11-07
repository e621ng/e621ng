# frozen_string_literal: true

module UploadsHelper
  def render_status(upload)
    search_params = params.fetch(:search, {}).permit!
    case upload.status
    when /duplicate: (\d+)/
      link_to(upload.status, post_path($1))

    when "failed"
      link_to("failed: #{upload.error_message.to_s.truncate(120)}", uploads_path(search: search_params.merge({ status: "failed" })))

    else
      link_to(upload.status, uploads_path(search: search_params.merge({ status: upload.status })))
    end
  end
end
