# frozen_string_literal: true

require "rails_helper"

RSpec.describe SidekiqCapsules do
  describe ".parse" do
    it "returns an empty array for nil or blank input" do
      expect(described_class.parse(nil)).to eq([])
      expect(described_class.parse("")).to eq([])
      expect(described_class.parse("  ;  ")).to eq([])
    end

    it "parses a single capsule with a default queue weight" do
      expect(described_class.parse("iqdb 1 iqdb")).to eq([
        { name: "iqdb", concurrency: 1, queues: [["iqdb", 1]] },
      ])
    end

    it "parses multiple capsules with explicit weights" do
      expect(described_class.parse("media 2 video:1,thumb:3; iqdb 1 iqdb:1")).to eq([
        { name: "media", concurrency: 2, queues: [["video", 1], ["thumb", 3]] },
        { name: "iqdb", concurrency: 1, queues: [["iqdb", 1]] },
      ])
    end

    it "tolerates extra whitespace" do
      expect(described_class.parse("  media   2   video:1 , thumb:1  ")).to eq([
        { name: "media", concurrency: 2, queues: [["video", 1], ["thumb", 1]] },
      ])
    end

    it "rejects capsules with empty names" do
      expect { described_class.parse("  2 video") }.to raise_error(ArgumentError, /expected "<name> <concurrency> <queues>", got "2 video"/)
    end

    it "rejects the reserved default capsule name" do
      expect { described_class.parse("default 5 low_prio") }.to raise_error(ArgumentError, /reserved/)
    end

    it "rejects duplicate capsule names" do
      expect { described_class.parse("media 2 video;media 1 thumb") }.to raise_error(ArgumentError, /duplicate/)
    end

    it "rejects capsules without queues" do
      expect { described_class.parse("media 2") }.to raise_error(ArgumentError, /expected/)
    end

    it "rejects non-integer concurrency" do
      expect { described_class.parse("media two video") }.to raise_error(ArgumentError, /concurrency/)
    end

    it "rejects zero concurrency" do
      expect { described_class.parse("media 0 video") }.to raise_error(ArgumentError, /concurrency/)
    end

    it "rejects invalid queue weights" do
      expect { described_class.parse("media 2 video:x") }.to raise_error(ArgumentError, /queue entry/)
      expect { described_class.parse("media 2 video:0") }.to raise_error(ArgumentError, /queue entry/)
    end

    it "rejects empty queue names" do
      expect { described_class.parse("media 2 :1") }.to raise_error(ArgumentError, /queue name cannot be empty/)
    end
  end
end
