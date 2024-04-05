# frozen_string_literal: true

module Sources
  module Alternates
    class Pixiv < Base
      MONIKER = %r!(?:[a-zA-Z0-9_-]+)!
      PROFILE = %r!\Ahttps?://www\.pixiv\.net/member\.php\?id=[0-9]+\z!
      DATE = %r!(?<date>\d{4}/\d{2}/\d{2}/\d{2}/\d{2}/\d{2})!i
      EXT = %r!(?:jpg|jpeg|png|gif)!i

      def force_https?
        true
      end

      def domains
        ["pixiv.net", "pximg.net"]
      end

      def parse
        id = illust_id
        if id
          @submission_url = "https://www.pixiv.net/artworks/#{id}"
        end
      end

      def remove_duplicates(sources)
        our_illust_id = illust_id
        return sources unless our_illust_id
        sources.delete_if do |source|
          url = Addressable::URI.heuristic_parse(source) rescue nil
          next false if url.nil?
          if url.host == "www.pixiv.net" && url.path == "/member_illust.php" && url.query_values.present? && url.query_values["illust_id"].present?
            next true if url.query_values["illust_id"].to_i == our_illust_id
          elsif url.host == "www.pixiv.net" && url.path =~ %r!\A/i/(?<illust_id>\d+)\z!i
            next true if $~[:illust_id].to_i == our_illust_id
          elsif url.host == "www.pixiv.net" && url.path =~ %r!\A/en/artworks/(?<illust_id>\d+)\z!i
            next true if $~[:illust_id].to_i == our_illust_id
          end
          false
        end
      end

      private

      def illust_id
        return 0 if parsed_url.nil?
        url = parsed_url
        # http://www.pixiv.net/member_illust.php?mode=medium&illust_id=18557054
        # http://www.pixiv.net/member_illust.php?mode=big&illust_id=18557054
        # http://www.pixiv.net/member_illust.php?mode=manga&illust_id=18557054
        # http://www.pixiv.net/member_illust.php?mode=manga_big&illust_id=18557054&page=1
        if url.host == "www.pixiv.net" && url.path == "/member_illust.php" && url.query_values.present? && url.query_values["illust_id"].present?
          return url.query_values["illust_id"].to_i

          # http://www.pixiv.net/i/18557054
        elsif url.host == "www.pixiv.net" && url.path =~ %r!\A/i/(?<illust_id>\d+)\z!i
          return $~[:illust_id].to_i
          # https://www.pixiv.net/en/artworks/80169645
          # https://www.pixiv.net/artworks/80169645
        elsif url.host == "www.pixiv.net" && url.path =~ %r!\A/(?:en/)?artworks/(?<illust_id>\d+)\z!i
          return $~[:illust_id].to_i

          # http://img18.pixiv.net/img/evazion/14901720.png
          # http://i2.pixiv.net/img18/img/evazion/14901720.png
          # http://i2.pixiv.net/img18/img/evazion/14901720_m.png
          # http://i2.pixiv.net/img18/img/evazion/14901720_s.png
          # http://i1.pixiv.net/img07/img/pasirism/18557054_p1.png
          # http://i1.pixiv.net/img07/img/pasirism/18557054_big_p1.png
        elsif url.host =~ %r!\A(?:i\d+|img\d+)\.pixiv\.net\z!i &&
            url.path =~ %r!\A(?:/img\d+)?/img/#{MONIKER}/(?<illust_id>\d+)(?:_\w+)?\.(?:jpg|jpeg|png|gif|zip)!i
          @direct_url = @url
          return $~[:illust_id].to_i

          # http://i1.pixiv.net/img-inf/img/2011/05/01/23/28/04/18557054_64x64.jpg
          # http://i1.pixiv.net/img-inf/img/2011/05/01/23/28/04/18557054_s.png
          # http://i1.pixiv.net/c/600x600/img-master/img/2014/10/02/13/51/23/46304396_p0_master1200.jpg
          # http://i1.pixiv.net/img-original/img/2014/10/02/13/51/23/46304396_p0.png
          # http://i1.pixiv.net/img-zip-ugoira/img/2014/10/03/17/29/16/46323924_ugoira1920x1080.zip
          # https://i.pximg.net/img-original/img/2014/10/03/18/10/20/46324488_p0.png
          # https://i.pximg.net/img-master/img/2014/10/03/18/10/20/46324488_p0_master1200.jpg
          #
          # but not:
          #
          # https://i.pximg.net/novel-cover-original/img/2019/01/14/01/15/05/10617324_d84daae89092d96bbe66efafec136e42.jpg
          # https://img-sketch.pixiv.net/uploads/medium/file/4463372/8906921629213362989.jpg
        elsif url.host =~ %r!\A(?:i\.pximg\.net|i\d+\.pixiv\.net)\z!i &&
            url.path =~ %r!\A(/c/\w+)?/img-[a-z-]+/img/#{DATE}/(?<illust_id>\d+)(?:_\w+)?\.(?:jpg|jpeg|png|gif|zip)!i
          @direct_url = @url
          return $~[:illust_id].to_i
        end

        return nil
      end
    end
  end
end
