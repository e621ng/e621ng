# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                    Danbooru configuration sanity checks                     #
# --------------------------------------------------------------------------- #

RSpec.describe Danbooru::EnvironmentConfiguration do
  describe "#validate!" do
    # validate! reads through Danbooru.config (method_missing -> ENV -> custom),
    # so stubbing custom_configuration drives the effective values.
    def stub_config(**values)
      allow(Danbooru.config.custom_configuration).to receive_messages(**values)
    end

    it "accepts the committed default configuration" do
      expect { Danbooru.config.validate! }.not_to raise_error
    end

    it "accepts a valid custom configuration" do
      stub_config(upload_karma_l1_threshold: 50, upload_karma_l10_threshold: 5_000, upload_karma_free_threshold: 3)
      expect { Danbooru.config.validate! }.not_to raise_error
    end

    context "upload_karma_l1_threshold" do
      it "raises when it is zero" do
        stub_config(upload_karma_l1_threshold: 0)
        expect { Danbooru.config.validate! }.to raise_error(described_class::ValidationError, /l1_threshold must be positive/)
      end

      it "raises when it is negative" do
        stub_config(upload_karma_l1_threshold: -5)
        expect { Danbooru.config.validate! }.to raise_error(described_class::ValidationError, /l1_threshold must be positive/)
      end
    end

    context "upload_karma_l10_threshold" do
      it "raises when it is not greater than l1" do
        stub_config(upload_karma_l1_threshold: 100, upload_karma_l10_threshold: 100)
        expect { Danbooru.config.validate! }.to raise_error(described_class::ValidationError, /must be less than upload_karma_l10_threshold/)
      end

      it "raises when it is negative" do
        stub_config(upload_karma_l10_threshold: -1)
        expect { Danbooru.config.validate! }.to raise_error(described_class::ValidationError)
      end
    end

    context "upload_karma_free_threshold" do
      it "allows nil (bypass disabled)" do
        stub_config(upload_karma_free_threshold: nil)
        expect { Danbooru.config.validate! }.not_to raise_error
      end

      it "accepts the boundary levels 1 and 10" do
        stub_config(upload_karma_free_threshold: 1)
        expect { Danbooru.config.validate! }.not_to raise_error
        stub_config(upload_karma_free_threshold: 10)
        expect { Danbooru.config.validate! }.not_to raise_error
      end

      it "raises when below 1" do
        stub_config(upload_karma_free_threshold: 0)
        expect { Danbooru.config.validate! }.to raise_error(described_class::ValidationError, /between 1 and 10/)
      end

      it "raises when above 10" do
        stub_config(upload_karma_free_threshold: 11)
        expect { Danbooru.config.validate! }.to raise_error(described_class::ValidationError, /between 1 and 10/)
      end
    end
  end
end
