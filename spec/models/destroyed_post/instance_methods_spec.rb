# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                    DestroyedPost Instance Methods                           #
# --------------------------------------------------------------------------- #

RSpec.describe DestroyedPost do
  let(:admin)    { create(:admin_user) }
  let(:uploader) { create(:user) }

  before { CurrentUser.user = admin }
  after  { CurrentUser.user = nil }

  describe "#notify_reupload" do
    before do
      allow(Cache.redis).to receive(:publish)
    end

    context "when notify is false" do
      let(:dp) { create(:destroyed_post, notify: false) }

      it "returns without creating a ticket" do
        expect { dp.notify_reupload(uploader) }.not_to change(Ticket, :count)
      end
    end

    context "when notify is true (default)" do
      let(:dp) { create(:destroyed_post, notify: true) }

      it "creates exactly one ticket" do
        expect { dp.notify_reupload(uploader) }.to change(Ticket, :count).by(1)
      end

      it "sets creator_id to the system user" do
        dp.notify_reupload(uploader)
        expect(Ticket.last.creator_id).to eq(User.system.id)
      end

      it "sets qtype to 'user'" do
        dp.notify_reupload(uploader)
        expect(Ticket.last.qtype).to eq("user")
      end

      it "sets disp_id to the uploader's id" do
        dp.notify_reupload(uploader)
        expect(Ticket.last.disp_id).to eq(uploader.id)
      end

      it "includes the post_id in the ticket reason" do
        dp.notify_reupload(uploader)
        expect(Ticket.last.reason).to include(dp.post_id.to_s)
      end

      it "does not mention replacement when replacement_post_id is absent" do
        dp.notify_reupload(uploader)
        expect(Ticket.last.reason).not_to include("replacement")
      end

      it "mentions the replacement post id when replacement_post_id is provided" do
        dp.notify_reupload(uploader, replacement_post_id: 42)
        expect(Ticket.last.reason).to include("replacement for post #42")
      end

      it "calls push_pubsub with 'create' on the new ticket" do
        ticket = instance_double(Ticket, push_pubsub: nil)
        allow(Ticket).to receive(:create!).and_return(ticket)
        allow(ticket).to receive(:push_pubsub)
        dp.notify_reupload(uploader)
        expect(ticket).to have_received(:push_pubsub).with("create")
      end
    end
  end
end
