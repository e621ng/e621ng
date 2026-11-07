# frozen_string_literal: true

# Upload validation looks up the md5 among queued/processing uploads on every submit.
class AddInFlightMd5IndexToUploads < ActiveRecord::Migration[8.1]
  def change
    add_index :uploads, :md5, name: "index_uploads_on_md5_in_flight", where: "status IN ('queued', 'processing')"
  end
end
