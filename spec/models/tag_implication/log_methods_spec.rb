# frozen_string_literal: true

require "rails_helper"

# ---------------------------------------------------------------------------
# TagImplication::ModAction Logging
#
# create_mod_action fires after every status change via after_save callback:
#   previously_new_record? == true  → logs :tag_implication_create
#   otherwise                       → logs :tag_implication_update (with change_desc)
# ---------------------------------------------------------------------------

RSpec.describe TagImplication do
  include_context "as admin"

  describe "#create_mod_action" do
    # The callback fires only when status changes (saved_change_to_status?).
    # Creating with the default status ("pending") is not a status change from
    # Rails's perspective (the DB default initialises the attribute), so the
    # create path is only exercised when the record is saved with a non-default
    # status — e.g. :active_tag_implication.
    describe "on create" do
      it "logs a tag_implication_create action" do
        create(:active_tag_implication)
        expect(ModAction.last.action).to eq("tag_implication_create")
      end

      it "includes the implication id in the log values" do
        ti = create(:active_tag_implication)
        expect(ModAction.last[:values]).to include("implication_id" => ti.id)
      end
    end

    describe "on update" do
      it "logs a tag_implication_update action" do
        ti = create(:tag_implication)
        ti.update!(status: "deleted")
        expect(ModAction.last.action).to eq("tag_implication_update")
      end

      it "includes the implication id and a change description in the log values" do
        ti = create(:tag_implication)
        ti.update!(status: "deleted")
        log = ModAction.last
        expect(log[:values]).to include("implication_id" => ti.id)
        expect(log[:values]["change_desc"]).to be_present
      end

      it "describes the changed attribute in change_desc" do
        ti = create(:tag_implication)
        ti.update!(status: "deleted")
        expect(ModAction.last[:values]["change_desc"]).to include("status")
      end
    end
  end

  # ---------------------------------------------------------------------------
  # #reject!
  # ---------------------------------------------------------------------------
  describe "#reject!" do
    it "sets status to deleted" do
      ti = create(:tag_implication)
      expect { ti.reject!(update_topic: false) }
        .to change { ti.reload.status }.to("deleted")
    end
  end
end
