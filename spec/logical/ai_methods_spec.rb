# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                              AiMethods                                      #
# --------------------------------------------------------------------------- #
#
# Covers:
#   - .build_token_regex(tokens)
#   - #is_ai_generated?(file_path)
#
# Uses build(:upload) as the host object because Upload includes AiMethods,
# consistent with the pattern in spec/logical/file_methods/file_utilities_spec.rb.
# No CurrentUser setup is needed — the method performs no DB access.

RSpec.describe AiMethods do
  let(:upload) { build(:upload) }

  # ----------------------------------------------------------------------- #
  describe ".build_token_regex" do
    it "returns a Regexp" do
      expect(AiMethods.build_token_regex(["novelai"])).to be_a(Regexp)
    end

    it "is case-insensitive" do
      regex = AiMethods.build_token_regex(["novelai"])
      expect(regex).to match("NovelAI generated image")
      expect(regex).to match("NOVELAI")
    end

    it "applies word boundaries to simple alpha-numeric tokens" do
      regex = AiMethods.build_token_regex(["comfy"])
      expect(regex).to match("comfy settings")
      expect(regex).not_to match("comfyui workflow")
    end

    it "does not apply word boundaries to tokens with special characters" do
      regex = AiMethods.build_token_regex(["steps:"])
      expect(regex).to match("Steps: 20")
      expect(regex).to match("footsteps:20")
    end
  end

  # ----------------------------------------------------------------------- #
  describe "#is_ai_generated?" do
    context "when the file extension is not a supported image type" do
      it "returns score 0 and reason 'not an image'" do
        result = upload.is_ai_generated?("/path/to/file.mp4")
        expect(result).to eq({ score: 0, reason: "not an image" })
      end

      it "treats an extension-less path as not an image" do
        result = upload.is_ai_generated?("/path/to/file")
        expect(result).to eq({ score: 0, reason: "not an image" })
      end
    end

    context "when the file does not exist" do
      it "returns score 0 and reason 'file not found'" do
        result = upload.is_ai_generated?("/nonexistent/path/image.png")
        expect(result).to eq({ score: 0, reason: "file not found" })
      end
    end

    context "with a NovelAI-generated PNG (ai/generator.png)" do
      it "returns score 100 and identifies the ai generator" do
        path = file_fixture("ai/generator.png").to_s
        result = upload.is_ai_generated?(path)
        expect(result[:score]).to eq(100)
        expect(result[:reason]).to include("ai generator")
      end
    end

    context "with a Stable Diffusion PNG (ai/tokens.png)" do
      it "returns score 60 and reports ai parameter tokens found" do
        path = file_fixture("ai/tokens.png").to_s
        result = upload.is_ai_generated?(path)
        expect(result[:score]).to eq(60)
        expect(result[:reason]).to include("ai parameter tokens found")
      end
    end

    context "with a clean PNG without AI metadata (sample.png)" do
      it "returns score 0 and reason 'no ai signals'" do
        path = file_fixture("sample.png").to_s
        result = upload.is_ai_generated?(path)
        expect(result).to eq({ score: 0, reason: "no ai signals" })
      end
    end

    context "with a clean JPEG without AI metadata (sample.jpg)" do
      it "returns score 0 and reason 'no ai signals'" do
        path = file_fixture("sample.jpg").to_s
        result = upload.is_ai_generated?(path)
        expect(result).to eq({ score: 0, reason: "no ai signals" })
      end
    end

    context "with a GIF without AI metadata (static.gif)" do
      it "returns score 0 and reason 'no ai signals'" do
        path = file_fixture("static.gif").to_s
        result = upload.is_ai_generated?(path)
        expect(result).to eq({ score: 0, reason: "no ai signals" })
      end
    end
  end
end
