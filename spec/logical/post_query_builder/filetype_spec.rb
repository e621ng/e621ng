# frozen_string_literal: true

require "rails_helper"

RSpec.describe PostQueryBuilder do
  include_context "as admin"

  def run(query)
    PostQueryBuilder.new(query).search
  end

  describe "filetype: metatag" do
    describe "filetype:png" do
      it "includes posts with file_ext png" do
        png = create(:post, file_ext: "png")
        expect(run("filetype:png")).to include(png)
      end

      it "excludes posts with a different file_ext" do
        jpg = create(:post, file_ext: "jpg")
        expect(run("filetype:png")).not_to include(jpg)
      end
    end

    describe "-filetype:png" do
      it "excludes posts with file_ext png" do
        png = create(:post, file_ext: "png")
        expect(run("-filetype:png")).not_to include(png)
      end

      it "includes posts with a different file_ext" do
        jpg = create(:post, file_ext: "jpg")
        expect(run("-filetype:png")).to include(jpg)
      end
    end
  end
end
