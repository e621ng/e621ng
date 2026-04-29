# frozen_string_literal: true

require "rails_helper"

# ---------------------------------------------------------------------------
# TagAlias::ModAction Logging
#
# create_mod_action fires after every save via after_save callback:
#   previously_new_record? == true  → logs :tag_alias_create
#   otherwise                       → logs :tag_alias_update (with change_desc)
# ---------------------------------------------------------------------------

RSpec.describe TagAlias do
  include_context "as admin"

  describe "#create_mod_action" do
    describe "on create" do
      it "logs a tag_alias_create action" do
        create(:tag_alias)
        log = ModAction.last
        expect(log.action).to eq("tag_alias_create")
      end

      it "includes the alias id in the log values" do
        ta = create(:tag_alias)
        log = ModAction.last
        expect(log[:values]).to include("alias_id" => ta.id)
      end
    end

    describe "on update" do
      it "logs a tag_alias_update action" do
        ta = create(:tag_alias)
        ta.update!(status: "deleted")
        log = ModAction.last
        expect(log.action).to eq("tag_alias_update")
      end

      it "includes the alias id and a change description in the log values" do
        ta = create(:tag_alias)
        ta.update!(status: "deleted")
        log = ModAction.last
        expect(log[:values]).to include("alias_id" => ta.id)
        expect(log[:values]["change_desc"]).to be_present
      end

      it "describes the changed attribute in change_desc" do
        ta = create(:tag_alias)
        ta.update!(status: "deleted")
        log = ModAction.last
        expect(log[:values]["change_desc"]).to include("status")
      end
    end
  end

  # ---------------------------------------------------------------------------
  # #reject!
  # ---------------------------------------------------------------------------
  describe "#reject!" do
    it "sets status to deleted" do
      ta = create(:tag_alias)
      expect { ta.reject!(update_topic: false) }
        .to change { ta.reload.status }.to("deleted")
    end
  end
end
