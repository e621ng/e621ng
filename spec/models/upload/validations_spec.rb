# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                           Upload Validations                                #
# --------------------------------------------------------------------------- #

RSpec.describe Upload do
  describe "validations" do
    # -------------------------------------------------------------------------
    # rating
    # -------------------------------------------------------------------------
    describe "rating" do
      it "is invalid without a rating" do
        upload = build(:upload, rating: nil)
        expect(upload).not_to be_valid
        expect(upload.errors[:rating]).to be_present
      end

      it "is invalid with a value outside the allowed set" do
        upload = build(:upload, rating: "x")
        expect(upload).not_to be_valid
        expect(upload.errors[:rating]).to be_present
      end

      it "is valid with rating 's'" do
        expect(build(:upload, rating: "s")).to be_valid
      end

      it "is valid with rating 'e'" do
        expect(build(:upload, rating: "e")).to be_valid
      end

      it "is valid with rating 'q'" do
        expect(build(:upload, rating: "q")).to be_valid
      end
    end

    # -------------------------------------------------------------------------
    # uploader_is_not_limited (on: :create)
    # -------------------------------------------------------------------------
    describe "uploader_is_not_limited" do
      it "is valid when the uploader can upload" do
        expect(build(:upload)).to be_valid
      end

      it "is invalid when the uploader cannot upload" do
        upload = build(:upload)
        allow(upload.uploader).to receive(:can_upload_with_reason).and_return(:restricted)
        expect(upload).not_to be_valid
        expect(upload.errors[:uploader]).to be_present
      end

      it "skips the check when replacement_id is present" do
        upload = build(:upload, replacement_id: 99)
        allow(upload.uploader).to receive(:can_upload_with_reason).and_return(:restricted)
        # only rating and whitelist validations remain; both pass for this build
        expect(upload.errors[:uploader]).to be_empty
      end
    end

    # -------------------------------------------------------------------------
    # md5_is_unique (on: :file)
    # -------------------------------------------------------------------------
    describe "md5_is_unique" do
      include_context "as member"

      let(:md5) { SecureRandom.hex(16) }

      def md5_errors(upload)
        upload.send(:md5_is_unique)
        upload.errors[:md5]
      end

      it "rejects an md5 held by an upload that is still being processed" do
        other = create(:upload, md5: md5, status: "queued")
        expect(md5_errors(build(:upload, md5: md5))).to include("is already being processed by upload ##{other.id}")
      end

      it "ignores finished uploads with the same md5" do
        create(:upload, md5: md5, status: "failed")
        expect(md5_errors(build(:upload, md5: md5))).to be_empty
      end

      it "does not count the upload against itself" do
        upload = create(:upload, md5: md5, status: "processing")
        expect(md5_errors(upload)).to be_empty
      end

      it "reports an existing post" do
        post = create(:post, md5: md5)
        expect(md5_errors(build(:upload, md5: md5))).to include("duplicate: #{post.id}")
      end
    end

    # -------------------------------------------------------------------------
    # direct_url_is_whitelisted (on: :create)
    # -------------------------------------------------------------------------
    describe "direct_url_is_whitelisted" do
      it "is valid when direct_url is nil" do
        expect(build(:upload, direct_url: nil)).to be_valid
      end

      it "is valid when direct_url is not an HTTP URL" do
        # direct_url_parsed returns nil for non-HTTP → validation short-circuits
        expect(build(:upload, direct_url: "local_file.png")).to be_valid
      end

      context "when direct_url is an HTTP URL" do
        before do
          # whitelist entries require CurrentUser for their ModAction callbacks
          CurrentUser.user = create(:moderator_user)

          # Prevent fixup_source from calling out to Sources::Strategies
          allow(Sources::Strategies).to receive(:find)
            .and_return(instance_double(Sources::Strategies::Base, canonical_url: nil))
        end

        after  { CurrentUser.user = nil }

        it "is invalid when the URL is not whitelisted" do
          upload = build(:upload, direct_url: "https://notwhitelisted.example.com/image.jpg")
          expect(upload).not_to be_valid
          expect(upload.errors[:source]).to be_present
        end

        it "is valid when the URL matches a whitelist entry" do
          create(:upload_whitelist, domain: "trusted\\.example\\.com", path: "\\/.+")
          upload = build(:upload, direct_url: "https://trusted.example.com/image.jpg")
          expect(upload).to be_valid
        end
      end
    end

    # -------------------------------------------------------------------------
    # direct_url_passes_rules (on: :create)
    # -------------------------------------------------------------------------
    describe "direct_url_passes_rules" do
      let(:url) { "https://example.com/sample/1.jpg" }

      before do
        CurrentUser.user = create(:moderator_user)
        allow(Sources::Strategies).to receive(:find)
          .and_return(instance_double(Sources::Strategies::Base, canonical_url: nil))
        allow(UploadWhitelist).to receive(:is_whitelisted?).and_return([true, nil])
      end

      after { CurrentUser.user = nil }

      it "is valid when no rule matches" do
        create(:blocking_upload_url_rule, pattern: "other\\.com/")
        expect(build(:upload, direct_url: url)).to be_valid
      end

      it "is valid when only a recommend rule matches" do
        create(:upload_url_rule)
        expect(build(:upload, direct_url: url)).to be_valid
      end

      it "is invalid when a block rule matches, naming the rule and the suggestion" do
        create(:blocking_upload_url_rule, label: "Sample URL", message: "Find the full size.")
        upload = build(:upload, direct_url: url)
        expect(upload).not_to be_valid
        expect(upload.errors[:source].first).to eq("is not allowed: Sample URL. Find the full size. Use https://example.com/full/1.jpg instead.")
      end

      it "is valid when a file is attached alongside a blocked URL" do
        create(:blocking_upload_url_rule)
        expect(build(:upload, direct_url: url, file: Tempfile.new)).to be_valid
      end

      it "is invalid when a rule fails to evaluate" do
        allow(UploadUrlRule).to receive(:evaluate).and_raise(UploadUrlRule::EvaluationError.new("Slow"))
        upload = build(:upload, direct_url: url)
        expect(upload).not_to be_valid
        expect(upload.errors[:source].first).to include("could not be checked: rule 'Slow' failed")
      end

      it "shows a fetch-time rule refusal as is" do
        error = Downloads::File::RuleError.new("'https://example.com/x' is not allowed: Sample URL.")
        expect(described_class.error_message_for(error)).to eq("'https://example.com/x' is not allowed: Sample URL.")
      end

      it "does not consult rules when a file is attached" do
        allow(UploadUrlRule).to receive(:evaluate).and_raise(UploadUrlRule::EvaluationError.new("Slow"))
        expect(build(:upload, direct_url: url, file: Tempfile.new)).to be_valid
      end
    end
  end
end
