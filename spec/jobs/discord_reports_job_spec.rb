# frozen_string_literal: true

require "rails_helper"

RSpec.describe DiscordReportsJob do
  describe "#perform" do
    let(:janitor) { instance_double(DiscordReport::JanitorStats) }
    let(:moderator) { instance_double(DiscordReport::ModeratorStats) }
    let(:aibur) { instance_double(DiscordReport::AiburStats) }

    before do
      allow(DiscordReport::JanitorStats).to receive(:new).and_return(janitor)
      allow(DiscordReport::ModeratorStats).to receive(:new).and_return(moderator)
      allow(DiscordReport::AiburStats).to receive(:new).and_return(aibur)
    end

    it "runs every report" do
      allow(janitor).to receive(:run!)
      allow(moderator).to receive(:run!)
      allow(aibur).to receive(:run!)

      described_class.new.perform

      expect(janitor).to have_received(:run!)
      expect(moderator).to have_received(:run!)
      expect(aibur).to have_received(:run!)
    end

    it "continues running later reports when an earlier one fails" do
      error = StandardError.new("webhook down")
      allow(janitor).to receive(:run!).and_raise(error)
      allow(moderator).to receive(:run!)
      allow(aibur).to receive(:run!)
      allow(DanbooruLogger).to receive(:log)

      described_class.new.perform

      expect(DanbooruLogger).to have_received(:log).with(error)
      expect(moderator).to have_received(:run!)
      expect(aibur).to have_received(:run!)
    end
  end
end
