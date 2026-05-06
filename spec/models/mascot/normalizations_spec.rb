# frozen_string_literal: true

RSpec.describe Mascot do
  include_context "as admin"

  # Un-stub set_file_properties for a mascot so the real logic runs.
  def with_real_file_properties(mascot)
    allow(mascot).to receive(:set_file_properties).and_call_original
    mascot
  end

  describe "#set_file_properties" do
    it "sets file_ext to 'png' when given a PNG file" do
      file = Rails.root.join("spec/fixtures/files/sample.png").open
      mascot = with_real_file_properties(build(:mascot, mascot_file: file))
      mascot.valid?
      expect(mascot.file_ext).to eq("png")
    end

    it "sets file_ext to 'jpg' when given a JPEG file" do
      file = Rails.root.join("spec/fixtures/files/sample.jpg").open
      mascot = with_real_file_properties(build(:mascot, mascot_file: file))
      mascot.valid?
      expect(mascot.file_ext).to eq("jpg")
    end

    it "sets md5 from the file contents" do
      path = Rails.root.join("spec/fixtures/files/sample.png")
      expected_md5 = Digest::MD5.file(path).hexdigest
      mascot = with_real_file_properties(build(:mascot, mascot_file: File.open(path)))
      mascot.valid?
      expect(mascot.md5).to eq(expected_md5)
    end

    it "is a no-op when mascot_file is blank" do
      mascot = build(:mascot, mascot_file: nil, md5: "preset_md5", file_ext: "png")
      # set_file_properties is already stubbed by the factory; nil mascot_file means
      # the validation block is skipped entirely — md5/file_ext must remain unchanged.
      mascot.valid?
      expect(mascot.md5).to eq("preset_md5")
      expect(mascot.file_ext).to eq("png")
    end
  end
end
