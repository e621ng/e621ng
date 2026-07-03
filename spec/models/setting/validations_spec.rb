# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                            Setting Validations                              #
# --------------------------------------------------------------------------- #

RSpec.describe Setting do
  describe "validations" do
    # -------------------------------------------------------------------------
    # uploads_min_level
    # -------------------------------------------------------------------------
    describe "uploads_min_level" do
      it "rejects nil" do
        expect { Setting.uploads_min_level = nil }.to raise_error(ActiveRecord::RecordInvalid)
      end

      it "rejects negative values" do
        expect { Setting.uploads_min_level = -1 }.to raise_error(ActiveRecord::RecordInvalid)
      end

      it "accepts zero" do
        expect { Setting.uploads_min_level = 0 }.not_to raise_error
      end
    end

    # -------------------------------------------------------------------------
    # hide_pending_posts_for
    # -------------------------------------------------------------------------
    describe "hide_pending_posts_for" do
      it "rejects nil" do
        expect { Setting.hide_pending_posts_for = nil }.to raise_error(ActiveRecord::RecordInvalid)
      end

      it "rejects negative values" do
        expect { Setting.hide_pending_posts_for = -1 }.to raise_error(ActiveRecord::RecordInvalid)
      end

      it "accepts zero" do
        expect { Setting.hide_pending_posts_for = 0 }.not_to raise_error
      end
    end

    # -------------------------------------------------------------------------
    # tos_version
    # -------------------------------------------------------------------------
    describe "tos_version" do
      it "rejects nil" do
        expect { Setting.tos_version = nil }.to raise_error(ActiveRecord::RecordInvalid)
      end

      it "rejects negative values" do
        expect { Setting.tos_version = -1 }.to raise_error(ActiveRecord::RecordInvalid)
      end

      it "rejects zero" do
        expect { Setting.tos_version = 0 }.to raise_error(ActiveRecord::RecordInvalid)
      end

      it "accepts positive values" do
        expect { Setting.tos_version = 1 }.not_to raise_error
      end
    end

    # -------------------------------------------------------------------------
    # trends_min_today
    # -------------------------------------------------------------------------
    describe "trends_min_today" do
      it "rejects nil" do
        expect { Setting.trends_min_today = nil }.to raise_error(ActiveRecord::RecordInvalid)
      end

      it "rejects negative values" do
        expect { Setting.trends_min_today = -1 }.to raise_error(ActiveRecord::RecordInvalid)
      end

      it "accepts zero" do
        expect { Setting.trends_min_today = 0 }.not_to raise_error
      end
    end

    # -------------------------------------------------------------------------
    # trends_min_delta
    # -------------------------------------------------------------------------
    describe "trends_min_delta" do
      it "rejects nil" do
        expect { Setting.trends_min_delta = nil }.to raise_error(ActiveRecord::RecordInvalid)
      end

      it "rejects negative values" do
        expect { Setting.trends_min_delta = -1 }.to raise_error(ActiveRecord::RecordInvalid)
      end

      it "accepts zero" do
        expect { Setting.trends_min_delta = 0 }.not_to raise_error
      end
    end

    # -------------------------------------------------------------------------
    # trends_min_ratio
    # -------------------------------------------------------------------------
    describe "trends_min_ratio" do
      it "rejects nil" do
        expect { Setting.trends_min_ratio = nil }.to raise_error(ActiveRecord::RecordInvalid)
      end

      it "rejects values below 1.0" do
        expect { Setting.trends_min_ratio = 0.9 }.to raise_error(ActiveRecord::RecordInvalid)
      end

      it "accepts exactly 1.0" do
        expect { Setting.trends_min_ratio = 1.0 }.not_to raise_error
      end
    end

    # -------------------------------------------------------------------------
    # trends_ip_limit  (must be > 0)
    # -------------------------------------------------------------------------
    describe "trends_ip_limit" do
      it "rejects nil" do
        expect { Setting.trends_ip_limit = nil }.to raise_error(ActiveRecord::RecordInvalid)
      end

      it "rejects zero" do
        expect { Setting.trends_ip_limit = 0 }.to raise_error(ActiveRecord::RecordInvalid)
      end

      it "rejects negative values" do
        expect { Setting.trends_ip_limit = -1 }.to raise_error(ActiveRecord::RecordInvalid)
      end

      it "accepts positive values" do
        expect { Setting.trends_ip_limit = 1 }.not_to raise_error
      end
    end

    # -------------------------------------------------------------------------
    # trends_ip_window  (must be > 0)
    # -------------------------------------------------------------------------
    describe "trends_ip_window" do
      it "rejects nil" do
        expect { Setting.trends_ip_window = nil }.to raise_error(ActiveRecord::RecordInvalid)
      end

      it "rejects zero" do
        expect { Setting.trends_ip_window = 0 }.to raise_error(ActiveRecord::RecordInvalid)
      end

      it "rejects negative values" do
        expect { Setting.trends_ip_window = -1 }.to raise_error(ActiveRecord::RecordInvalid)
      end

      it "accepts positive values" do
        expect { Setting.trends_ip_window = 1 }.not_to raise_error
      end
    end

    # -------------------------------------------------------------------------
    # trends_tag_limit  (must be > 0)
    # -------------------------------------------------------------------------
    describe "trends_tag_limit" do
      it "rejects nil" do
        expect { Setting.trends_tag_limit = nil }.to raise_error(ActiveRecord::RecordInvalid)
      end

      it "rejects zero" do
        expect { Setting.trends_tag_limit = 0 }.to raise_error(ActiveRecord::RecordInvalid)
      end

      it "rejects negative values" do
        expect { Setting.trends_tag_limit = -1 }.to raise_error(ActiveRecord::RecordInvalid)
      end

      it "accepts positive values" do
        expect { Setting.trends_tag_limit = 1 }.not_to raise_error
      end
    end

    # -------------------------------------------------------------------------
    # trends_tag_window  (must be > 0)
    # -------------------------------------------------------------------------
    describe "trends_tag_window" do
      it "rejects nil" do
        expect { Setting.trends_tag_window = nil }.to raise_error(ActiveRecord::RecordInvalid)
      end

      it "rejects zero" do
        expect { Setting.trends_tag_window = 0 }.to raise_error(ActiveRecord::RecordInvalid)
      end

      it "rejects negative values" do
        expect { Setting.trends_tag_window = -1 }.to raise_error(ActiveRecord::RecordInvalid)
      end

      it "accepts positive values" do
        expect { Setting.trends_tag_window = 1 }.not_to raise_error
      end
    end
  end
end
