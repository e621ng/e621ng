# frozen_string_literal: true

require "rails_helper"
require Rails.root.join("db/populate")

RSpec.describe Populate::BulkUpdateRequests, :populate_exports do
  include_context "as admin"

  let(:dir) { Dir.mktmpdir }

  after { FileUtils.rm_rf(dir) }

  it "imports requests without their forum references" do
    bur = create(:approved_bulk_update_request, title: "Dragons")
    bur.update_columns(user_id: 777_777, approver_id: 777_778, forum_topic_id: 55, forum_post_id: 56)
    write_export("bulk_update_requests", dir)
    BulkUpdateRequest.delete_all

    expect { expect(described_class.new(dir: dir).call).to eq(1) }.to output(/bulk update requests: 1 inserted/).to_stdout

    expect(BulkUpdateRequest.find(bur.id)).to have_attributes(
      script: bur.script, status: "approved", title: "Dragons", user_id: 777_777, approver_id: 777_778, forum_topic_id: nil, forum_post_id: nil,
    )
    expect(User.where(id: [777_777, 777_778]).count).to eq(2)
    expect { expect(described_class.new(dir: dir).call).to eq(0) }.to output.to_stdout
  end
end
