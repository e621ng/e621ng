# frozen_string_literal: true

require "rails_helper"

RSpec.describe WikiTableOfContents do
  def entries(html)
    described_class.new(html).entries
  end

  def rendered(html)
    described_class.new(html).html
  end

  def section(title, body = "<div><p>Skarn</p></div>")
    "<details><summary>#{title}</summary>#{body}</details>"
  end

  describe "#entries" do
    describe "headers" do
      it "extracts a header as an entry" do
        expect(entries("<h2>Vaelor</h2>")).to eq([{ depth: 0, slug: "vaelor", text: "Vaelor" }])
      end

      it "nests headers by level" do
        result = entries("<h1>Vaelor</h1><h2>Draketh</h2>")
        expect(result.map { |e| [e[:depth], e[:slug]] }).to eq([[0, "vaelor"], [1, "draketh"]])
      end

      it "uses structural (tree) depth, so a level maps to different depths by position" do
        result = entries("<h6>Vaelor</h6><h1>Draketh</h1><h6>Ignyr</h6>")
        expect(result.pluck(:depth)).to eq([0, 0, 1])
      end

      it "omits a header whose text yields no slug" do
        expect(entries("<h2>###</h2>")).to eq([])
      end
    end

    describe "slugs" do
      it "lowercases and hyphenates" do
        expect(entries("<h2>Vaelor Draketh</h2>").first[:slug]).to eq("vaelor-draketh")
      end

      it "keeps letters of any script" do
        expect(entries("<h2>Ðrako</h2>").first[:slug]).to eq("ðrako")
      end

      it "drops a parenthetical qualifier" do
        expect(entries("<h2>Vaelor (Draketh)</h2>").first[:slug]).to eq("vaelor")
      end

      it "falls back to the full text when dropping parentheticals empties the slug" do
        expect(entries("<h2>(Vaelor)</h2>").first).to include(slug: "vaelor", text: "(Vaelor)")
      end

      it "suffixes a colliding slug so each entry stays linkable" do
        expect(entries("<h2>Vaelor</h2><h2>Vaelor</h2>").pluck(:slug)).to eq(%w[vaelor vaelor-1])
      end

      it "increments the suffix past an existing numbered slug" do
        result = entries("<h2>Vaelor</h2><h2>Vaelor 1</h2><h2>Vaelor</h2>")
        expect(result.pluck(:slug)).to eq(%w[vaelor vaelor-1 vaelor-2])
      end

      it "suffixes a generated slug that collides with an author anchor" do
        result = entries(%(<h2>Vaelor <a id="vaelor"></a></h2><h2>Vaelor</h2>))
        expect(result.pluck(:slug)).to eq(%w[vaelor vaelor-1])
      end

      it "suffixes a generated slug that collides with a later author anchor" do
        result = entries(%(<h2>Vaelor</h2><h2>Draketh <a id="vaelor"></a></h2>))
        expect(result.pluck(:slug)).to eq(%w[vaelor-1 vaelor])
      end

      it "reserves an explicit id attribute so a generated slug avoids it" do
        result = entries(%(<h2 id="vaelor">Draketh</h2><h2>Vaelor</h2>))
        expect(result.pluck(:slug)).to eq(%w[vaelor vaelor-1])
      end

      it "suffixes a section slug that collides with a header" do
        result = entries("<h2>Vaelor</h2><h3>Draketh</h3>#{section('Vaelor')}")
        expect(result.pluck(:slug)).to eq(%w[vaelor draketh vaelor-1])
      end
    end

    describe "labels" do
      it "strips a leading or trailing nav glyph but keeps a mid-text one" do
        expect(entries("<h2>↑ Vaelor</h2>").first[:text]).to eq("Vaelor")
        expect(entries("<h2>Vaelor ^</h2>").first[:text]).to eq("Vaelor")
        expect(entries("<h2>Vaelor^Draketh</h2>").first[:text]).to eq("Vaelor^Draketh")
      end

      it "strips a back-to-top link and a trailing colon" do
        expect(entries(%(<h2><a href="#top">↑</a> Vaelor:</h2>)).first).to include(slug: "vaelor", text: "Vaelor")
      end

      it "strips inner markup from the label" do
        expect(entries("<h2>Vaelor <b>Draketh</b></h2>").first[:text]).to eq("Vaelor Draketh")
      end

      it "strips inner markup carrying a bracket in an attribute" do
        expect(entries(%(<h2><span title="Vaelor > Draketh">Ignyr</span></h2>)).first[:text]).to eq("Ignyr")
      end
    end

    describe "author anchors" do
      it "reuses an author anchor as the slug" do
        expect(entries(%(<h2>Vaelor <a id="wyrmroost"></a></h2>)).first[:slug]).to eq("wyrmroost")
      end

      it "does not read data-id as an anchor" do
        expect(entries(%(<h2>Vaelor <a data-id="123">Draketh</a></h2>)).first[:slug]).to eq("vaelor-draketh")
      end
    end

    describe "sections" do
      it "extracts a section summary as an entry" do
        expect(entries(section("Emberden")).first).to include(slug: "emberden", text: "Emberden")
      end

      it "nests a section under a preceding header" do
        result = entries("<h2>Vaelor</h2>#{section('Emberden')}")
        expect(result.map { |e| [e[:depth], e[:slug]] }).to eq([[0, "vaelor"], [1, "emberden"]])
      end

      it "nests sections by DOM depth" do
        result = entries(section("Emberden", "<div>#{section('Frostmaw')}</div>"))
        expect(result.map { |e| [e[:depth], e[:slug]] }).to eq([[0, "emberden"], [1, "frostmaw"]])
      end

      it "merges a header with an immediately following same-slug section" do
        result = entries("<h2>Emberden</h2>#{section('Emberden', '<div><h3>Draketh</h3></div>')}")
        expect(result.map { |e| [e[:depth], e[:slug]] }).to eq([[0, "emberden"], [1, "draketh"]])
      end
    end

    it "returns nothing for a body with no headers or sections" do
      expect(entries("<p>Skarn</p>")).to eq([])
    end
  end

  describe "#html" do
    it "injects an id onto a header" do
      expect(rendered("<h2>Vaelor</h2>")).to eq(%(<h2 id="vaelor">Vaelor</h2>))
    end

    it "injects an id onto a section summary" do
      expect(rendered(section("Emberden"))).to include(%(<summary id="emberden">))
    end

    it "leaves a header untouched when it already carries an author anchor" do
      html = %(<h2>Vaelor <a id="wyrmroost"></a></h2>)
      expect(rendered(html)).to eq(html)
    end

    it "injects a suffixed id onto a colliding header" do
      expect(rendered("<h2>Vaelor</h2><h2>Vaelor</h2>")).to eq(%(<h2 id="vaelor">Vaelor</h2><h2 id="vaelor-1">Vaelor</h2>))
    end

    it "leaves the body byte-identical except for injected ids" do
      html = %(<h2>Vaelor</h2><p>Skarn &quot;Glimmerscale&quot;  Hoard</p>#{section('Emberden', '<div><p>Cinder</p></div>')})
      strip_ids = ->(text) { text.gsub(/ id="[^"]*"/, "") }
      expect(strip_ids.call(rendered(html))).to eq(strip_ids.call(html))
    end
  end
end
