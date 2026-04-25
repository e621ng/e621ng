# frozen_string_literal: true

require "rails_helper"

RSpec.describe ElasticPostQueryBuilder do
  include_context "as member"

  def build_query(query_string, **opts)
    ElasticPostQueryBuilder.new(query_string, resolve_aliases: false, enable_safe_mode: false, **opts)
  end

  describe "numeric range metatags" do
    describe "score" do
      it "adds a gt range to must for score:>5" do
        expect(build_query("score:>5").must).to include({ range: { score: { gt: 5 } } })
      end

      it "adds a lt range to must for score:<5" do
        expect(build_query("score:<5").must).to include({ range: { score: { lt: 5 } } })
      end

      it "adds an exact term to must for score:5" do
        expect(build_query("score:5").must).to include({ term: { score: 5 } })
      end

      it "adds a gt range to must_not for -score:>5" do
        expect(build_query("-score:>5").must_not).to include({ range: { score: { gt: 5 } } })
      end

      it "adds a gt range to should for ~score:>5" do
        expect(build_query("~score:>5").should).to include({ range: { score: { gt: 5 } } })
      end
    end

    describe "id (post_id metatag)" do
      it "adds a range clause for id:>100" do
        expect(build_query("id:>100").must).to include({ range: { id: { gt: 100 } } })
      end
    end

    describe "mpixels" do
      it "adds a range clause for mpixels:>2" do
        expect(build_query("mpixels:>2").must).to include({ range: { mpixels: { gt: 2.0 } } })
      end
    end

    describe "ratio (maps to aspect_ratio)" do
      it "adds a range clause for ratio:>1" do
        expect(build_query("ratio:>1").must).to include({ range: { aspect_ratio: { gt: 1.0 } } })
      end
    end

    describe "width" do
      it "adds a range clause for width:>1920" do
        expect(build_query("width:>1920").must).to include({ range: { width: { gt: 1920 } } })
      end
    end

    describe "height" do
      it "adds a range clause for height:<720" do
        expect(build_query("height:<720").must).to include({ range: { height: { lt: 720 } } })
      end
    end

    describe "duration" do
      it "adds a range clause for duration:>60" do
        expect(build_query("duration:>60").must).to include({ range: { duration: { gt: 60.0 } } })
      end
    end

    describe "favcount (maps to fav_count)" do
      it "adds a range clause for favcount:>10" do
        expect(build_query("favcount:>10").must).to include({ range: { fav_count: { gt: 10 } } })
      end
    end

    describe "filesize (maps to file_size)" do
      it "adds a range clause for filesize:>1024" do
        expect(build_query("filesize:>1024").must).to include({ range: { file_size: { gt: 1024 } } })
      end
    end

    describe "change (maps to change_seq)" do
      it "adds a range clause for change:>500" do
        expect(build_query("change:>500").must).to include({ range: { change_seq: { gt: 500 } } })
      end
    end

    describe "date / age (map to created_at)" do
      it "adds an exact-day range for date:2024-01-01" do
        result = build_query("date:2024-01-01").must
        range_clause = result.find { |c| c.dig(:range, :created_at) }
        expect(range_clause).to be_present
        expect(range_clause.dig(:range, :created_at)).to have_key(:gte)
        expect(range_clause.dig(:range, :created_at)).to have_key(:lte)
      end

      it "adds a range clause for age:<1d" do
        result = build_query("age:<1d").must
        range_clause = result.find { |c| c.dig(:range, :created_at) }
        expect(range_clause).to be_present
      end
    end

    describe "tagcount (maps to tag_count)" do
      it "adds a term for tagcount:10" do
        expect(build_query("tagcount:10").must).to include({ term: { tag_count: 10 } })
      end

      it "adds a range clause for tagcount:>5" do
        expect(build_query("tagcount:>5").must).to include({ range: { tag_count: { gt: 5 } } })
      end
    end

    describe "category tag count metatags" do
      it "adds a range clause for gentags:>2 (maps to tag_count_general)" do
        expect(build_query("gentags:>2").must).to include({ range: { "tag_count_general" => { gt: 2 } } })
      end

      it "adds a range clause for arttags:>1 (maps to tag_count_artist)" do
        expect(build_query("arttags:>1").must).to include({ range: { "tag_count_artist" => { gt: 1 } } })
      end

      it "adds a range clause for chartags:>0 (maps to tag_count_character)" do
        expect(build_query("chartags:>0").must).to include({ range: { "tag_count_character" => { gt: 0 } } })
      end
    end

    describe "comment_count (COUNT_METATAG)" do
      it "adds a range clause for comment_count:>3" do
        result = build_query("comment_count:>3").must
        range_clause = result.find { |c| c.dig(:range, :comment_count) }
        expect(range_clause).to be_present
        expect(range_clause.dig(:range, :comment_count)).to eq({ gt: 3 })
      end

      it "adds an exact term for comment_count:5" do
        result = build_query("comment_count:5").must
        expect(result).to include({ term: { comment_count: 5 } })
      end
    end

    describe "md5" do
      it "adds a match_any of md5 terms for md5:abc123" do
        clause = { bool: { minimum_should_match: 1, should: [{ term: { md5: "abc123" } }] } }
        expect(build_query("md5:abc123").must).to include(clause)
      end

      it "adds all provided hashes in a single match_any for md5:abc123,def456" do
        clause = {
          bool: {
            minimum_should_match: 1,
            should: [{ term: { md5: "abc123" } }, { term: { md5: "def456" } }],
          },
        }
        expect(build_query("md5:abc123,def456").must).to include(clause)
      end
    end
  end
end
