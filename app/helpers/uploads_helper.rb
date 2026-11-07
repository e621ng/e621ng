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

  # The upload form, prefilled with what the user typed for a failed upload.
  # Query names match what the uploader reads on mount (pages/uploads/new/uploader.vue).
  def upload_retry_path(upload)
    query = {
      tags: upload.submitted_tag_string.presence || upload.tag_string.presence,
      sources: upload.source.to_s.split("\n").compact_blank.join(",").presence,
      rating: upload.rating,
      parent: upload.parent_id,
      description: upload.description.presence,
    }
    query[:locked_tags] = upload.locked_tags if upload.locked_tags.present?
    query[:rating_locked] = "true" if upload.locked_rating?
    query[:upload_as_pending] = "true" if upload.as_pending?
    new_upload_path(query.compact)
  end
end
