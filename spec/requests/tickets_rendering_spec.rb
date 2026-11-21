# frozen_string_literal: true

require "rails_helper"

# Render smoke test for every ticket type's show and new templates (doc 45).
# Only asserts on status codes: the markup is expected to change.
RSpec.describe TicketsController do
  include_context "as admin"

  # qtype => [factory trait, trait's transient key, content builder]
  qtypes = {
    "user"        => [nil,               :accused_user,     -> { create(:user) }],
    "blip"        => [:blip_type,        :blip,             -> { create(:blip) }],
    "comment"     => [:comment_type,     :comment,          -> { create(:comment) }],
    "dmail"       => [:dmail_type,       :dmail,            -> { create(:dmail, to: reporter) }],
    "forum"       => [:forum_type,       :forum_post,       -> { create(:forum_post) }],
    "pool"        => [:pool_type,        :pool,             -> { create(:pool) }],
    "post"        => [:post_type,        :post,             -> { create(:post) }],
    "set"         => [:set_type,         :post_set,         -> { create(:public_post_set) }],
    "wiki"        => [:wiki_type,        :wiki_page,        -> { create(:wiki_page) }],
    "replacement" => [:replacement_type, :post_replacement, -> { create(:post_replacement) }],
  }

  let(:reporter) { create(:user) }
  let(:admin)    { create(:admin_user) }

  missing = Ticket::VALID_QTYPES - qtypes.keys
  raise "Add the #{missing.join(', ')} ticket type(s) to #{__FILE__}" if missing.any?

  qtypes.each do |qtype, (trait, key, builder)|
    context "with a #{qtype} ticket" do
      let(:content) { instance_exec(&builder) }
      let(:ticket) do
        CurrentUser.scoped(reporter) { create(:ticket, *[trait].compact, key => content) }
      end

      it "renders new for the reporter" do
        sign_in_as reporter
        get new_ticket_path(qtype: qtype, disp_id: content.id)
        expect(response).to have_http_status(:ok)
      end

      it "re-renders new after a failed create" do
        sign_in_as reporter
        params = { qtype: qtype, disp_id: content.id, reason: "" }
        params[:report_reason] = create(:post_report_reason).reason if qtype == "post"
        expect { post tickets_path, params: { ticket: params } }.not_to change(Ticket, :count)
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("ticket-new-errors")
      end

      it "renders show for the reporter" do
        sign_in_as reporter
        get ticket_path(ticket)
        expect(response).to have_http_status(:ok)
      end

      it "renders show for an admin while pending" do
        sign_in_as admin
        get ticket_path(ticket)
        expect(response).to have_http_status(:ok)
      end

      it "renders show for an admin while claimed and under investigation" do
        ticket.update_columns(status: "partial", claimant_id: admin.id)
        sign_in_as admin
        get ticket_path(ticket)
        expect(response).to have_http_status(:ok)
      end

      it "renders show for an admin once handled" do
        ticket.update_columns(status: "approved", response: "Handled.", handler_id: admin.id, claimant_id: admin.id)
        sign_in_as admin
        get ticket_path(ticket)
        expect(response).to have_http_status(:ok)
      end

      it "renders show for an admin when the content is gone" do
        # Same view state as destroyed content, without FK constraints or destroy callbacks
        ticket.update_columns(disp_id: 0)
        sign_in_as admin
        get ticket_path(ticket)
        expect(response).to have_http_status(:ok)
      end
    end
  end

  it "renders the related ticket lists for an admin" do
    accused = create(:user)
    ticket = CurrentUser.scoped(reporter) { create(:ticket, accused_user: accused) }
    CurrentUser.scoped(reporter) { create(:ticket, :pool_type) }
    duplicate = CurrentUser.scoped(create(:user)) { create(:ticket, accused_user: accused) }
    duplicate.update_columns(status: "approved")

    sign_in_as admin
    get ticket_path(ticket)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("other open tickets", "Other tickets for this user")
  end
end
