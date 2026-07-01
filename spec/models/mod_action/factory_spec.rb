# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                           Factory sanity checks                             #
# --------------------------------------------------------------------------- #

RSpec.describe ModAction do
  # initialize_creator sets creator_id = CurrentUser.id on before_validation.
  # All factory uses require a CurrentUser to be set so the FK is valid.
  include_context "as admin"

  describe "factory" do
    it "produces a valid mod_action" do
      expect(create(:mod_action)).to be_persisted
    end
  end
end
