# frozen_string_literal: true

require "rails_helper"

RSpec.describe StorageManager do
  subject(:manager) { described_class.new(base_url: "http://example.com") }

  describe "#store" do
    it "raises NotImplementedError" do
      expect { manager.store(nil, "/path") }.to raise_error(NotImplementedError)
    end
  end

  describe "#delete" do
    it "raises NotImplementedError" do
      expect { manager.delete("/path") }.to raise_error(NotImplementedError)
    end
  end

  describe "#open" do
    it "raises NotImplementedError" do
      expect { manager.open("/path") }.to raise_error(NotImplementedError)
    end
  end

  describe "#move_file_delete" do
    it "raises NotImplementedError" do
      expect { manager.move_file_delete(nil) }.to raise_error(NotImplementedError)
    end
  end

  describe "#move_file_undelete" do
    it "raises NotImplementedError" do
      expect { manager.move_file_undelete(nil) }.to raise_error(NotImplementedError)
    end
  end
end
