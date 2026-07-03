# frozen_string_literal: true

require "rails_helper"

RSpec.describe BulkUpdateRequest do
  include_context "as admin"

  describe "normalize_text" do
    it "downcases the script on save" do
      bur = create(:bulk_update_request, script: "Create Alias ANT_TAG -> CON_TAG")
      expect(bur.script).to eq("alias ant_tag -> con_tag")
    end

    it "applies normalization on update as well" do
      bur = create(:bulk_update_request)
      bur.update!(script: "Create Alias UPPER_TAG -> OTHER_TAG")
      expect(bur.script).to eq("create alias upper_tag -> other_tag")
    end
  end

  describe "initialize_attributes" do
    it "sets user_id from CurrentUser when not provided" do
      bur = BulkUpdateRequest.new(script: "alias bur_init_ant -> bur_init_con", title: "test", skip_forum: true)
      bur.valid?
      expect(bur.user_id).to eq(CurrentUser.user.id)
    end

    it "does not override user_id when already set" do
      other_user = create(:user)
      bur = create(:bulk_update_request, user: other_user)
      expect(bur.user_id).to eq(other_user.id)
    end

    it "sets user_ip_addr from CurrentUser" do
      bur = BulkUpdateRequest.new(script: "alias bur_ip_ant -> bur_ip_con", title: "test", skip_forum: true)
      bur.valid?
      expect(bur.user_ip_addr).to eq(CurrentUser.ip_addr)
    end

    it "always sets status to pending on create" do
      bur = create(:bulk_update_request)
      expect(bur.status).to eq("pending")
    end
  end

  describe "validate_script script rewrite" do
    it "normalizes the script to untokenized canonical form on create" do
      bur = create(:bulk_update_request, script: "create alias rewrite_ant -> rewrite_con")
      expect(bur.script).to eq("alias rewrite_ant -> rewrite_con")
    end

    it "annotates the script with a duplicate comment when the alias already exists" do
      existing = create(:tag_alias, antecedent_name: "dup_ant", consequent_name: "dup_con")
      bur = create(:bulk_update_request, script: "create alias dup_ant -> dup_con")
      expect(bur.script).to match(/# duplicate of alias ##{existing.id}/)
    end
  end
end
