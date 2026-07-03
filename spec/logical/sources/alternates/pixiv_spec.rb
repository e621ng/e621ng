# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                     Sources::Alternates::Pixiv                              #
# --------------------------------------------------------------------------- #

RSpec.describe Sources::Alternates::Pixiv do
  def transform(url)
    described_class.new(url).original_url
  end

  def submission_url_for(url)
    described_class.new(url).submission_url
  end

  # -------------------------------------------------------------------------
  # #match?
  # -------------------------------------------------------------------------
  describe "#match?" do
    it "matches pixiv.net" do
      expect(described_class.new("https://www.pixiv.net/artworks/80169645").match?).to be true
    end

    it "matches pximg.net" do
      expect(described_class.new("https://i.pximg.net/img-master/img/2014/10/02/13/51/23/46304396_p0_master1200.jpg").match?).to be true
    end

    it "does not match unrelated domains" do
      expect(described_class.new("https://example.com/foo").match?).to be false
    end
  end

  # -------------------------------------------------------------------------
  # #original_url — submission page canonicalization
  # -------------------------------------------------------------------------
  describe "#original_url — submission page canonicalization" do
    it "canonicalizes member_illust.php?illust_id= URL" do
      expect(transform("https://www.pixiv.net/member_illust.php?mode=medium&illust_id=18557054")).to eq("https://www.pixiv.net/artworks/18557054")
    end

    it "canonicalizes member_illust.php with manga mode" do
      expect(transform("https://www.pixiv.net/member_illust.php?mode=manga&illust_id=18557054")).to eq("https://www.pixiv.net/artworks/18557054")
    end

    it "canonicalizes member_illust.php with manga_big mode and page param" do
      expect(transform("https://www.pixiv.net/member_illust.php?mode=manga_big&illust_id=18557054&page=1")).to eq("https://www.pixiv.net/artworks/18557054")
    end

    it "canonicalizes /i/{id} short URLs" do
      expect(transform("https://www.pixiv.net/i/18557054")).to eq("https://www.pixiv.net/artworks/18557054")
    end

    it "passes through already-canonical /artworks/{id} URLs" do
      expect(transform("https://www.pixiv.net/artworks/80169645")).to eq("https://www.pixiv.net/artworks/80169645")
    end

    it "canonicalizes /en/artworks/{id} to /artworks/{id}" do
      expect(transform("https://www.pixiv.net/en/artworks/80169645")).to eq("https://www.pixiv.net/artworks/80169645")
    end

    it "returns the URL unchanged for non-submission pixiv.net pages" do
      url = "https://www.pixiv.net/ranking.php"
      expect(transform(url)).to eq(url)
    end

    it "returns the URL unchanged for img-sketch.pixiv.net (no id_from_submission match)" do
      url = "https://img-sketch.pixiv.net/uploads/medium/file/4463372/8906921629213362989.jpg"
      expect(transform(url)).to eq(url)
    end
  end

  # -------------------------------------------------------------------------
  # #original_url — profile page canonicalization
  # -------------------------------------------------------------------------
  describe "#original_url — profile page canonicalization" do
    it "canonicalizes /en/users/{id} to /users/{id}" do
      expect(transform("https://www.pixiv.net/en/users/107143906")).to eq("https://www.pixiv.net/users/107143906")
    end

    it "canonicalizes member.php?id={id} to /users/{id}" do
      expect(transform("https://www.pixiv.net/member.php?id=923628")).to eq("https://www.pixiv.net/users/923628")
    end
  end

  # -------------------------------------------------------------------------
  # #submission_url — extracted from image URLs during parse
  # -------------------------------------------------------------------------
  describe "#submission_url — extracted from image URLs during parse" do
    it "extracts submission URL from old img18.pixiv.net image URL" do
      expect(submission_url_for("https://img18.pixiv.net/img/evazion/14901720.png")).to eq("https://www.pixiv.net/artworks/14901720")
    end

    it "extracts submission URL from old i2.pixiv.net image URL with size suffix" do
      expect(submission_url_for("https://i2.pixiv.net/img18/img/evazion/14901720_s.png")).to eq("https://www.pixiv.net/artworks/14901720")
    end

    it "extracts submission URL from i1.pixiv.net img-original image URL" do
      expect(submission_url_for("https://i1.pixiv.net/img-original/img/2014/10/02/13/51/23/46304396_p0.png")).to eq("https://www.pixiv.net/artworks/46304396")
    end

    it "extracts submission URL from i.pximg.net img-master image URL" do
      expect(submission_url_for("https://i.pximg.net/img-master/img/2014/10/03/18/10/20/46324488_p0_master1200.jpg")).to eq("https://www.pixiv.net/artworks/46324488")
    end

    it "extracts submission URL from i.pximg.net img-original image URL" do
      expect(submission_url_for("https://i.pximg.net/img-original/img/2014/10/03/18/10/20/46324488_p0.png")).to eq("https://www.pixiv.net/artworks/46324488")
    end

    it "extracts submission URL from i1.pixiv.net img-zip-ugoira URL" do
      expect(submission_url_for("https://i1.pixiv.net/img-zip-ugoira/img/2014/10/03/17/29/16/46323924_ugoira1920x1080.zip")).to eq("https://www.pixiv.net/artworks/46323924")
    end

    it "extracts submission URL from i1.pixiv.net thumbnail URL with /c/ prefix" do
      expect(submission_url_for("https://i1.pixiv.net/c/600x600/img-master/img/2014/10/02/13/51/23/46304396_p0_master1200.jpg")).to eq("https://www.pixiv.net/artworks/46304396")
    end

    it "does not set submission_url for novel-cover-original (hex hash filename)" do
      # The filename has a hex hash after the underscore, which does not match \d+
      expect(submission_url_for("https://i.pximg.net/novel-cover-original/img/2019/01/14/01/15/05/10617324_d84daae89092d96bbe66efafec136e42.jpg")).to be_nil
    end

    it "does not set submission_url for img-sketch.pixiv.net uploads (wrong host)" do
      expect(submission_url_for("https://img-sketch.pixiv.net/uploads/medium/file/4463372/8906921629213362989.jpg")).to be_nil
    end

    it "sets submission_url to nil for plain submission page URLs" do
      expect(submission_url_for("https://www.pixiv.net/artworks/80169645")).to be_nil
    end
  end
end
