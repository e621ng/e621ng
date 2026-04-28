# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                           Factory sanity checks                             #
# --------------------------------------------------------------------------- #

RSpec.describe Ban do
  # ModAction.log (after_create callback) calls initialize_creator which reads
  # CurrentUser.id. Setting a moderator satisfies this and the user_is_inferior
  # validation (moderators can ban regular members).
  let(:moderator) { create(:moderator_user) }

  before { CurrentUser.user = moderator }
  after  { CurrentUser.user = nil }

  describe "factory" do
    it "produces a valid timed ban" do
      expect(create(:ban, banner: moderator)).to be_persisted
    end

    it "produces a valid permanent ban" do
      expect(create(:permaban, banner: moderator)).to be_persisted
    end
  end
end
