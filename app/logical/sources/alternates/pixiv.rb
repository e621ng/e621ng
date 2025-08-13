# frozen_string_literal: true

module Sources
  module Alternates
    class Pixiv < Base
      MONIKER = /(?:[a-zA-Z0-9_-]+)/
      DATE = %r!(?<date>\d{4}/\d{2}/\d{2}/\d{2}/\d{2}/\d{2})!i
      EXT = /\.(?:jpg|jpeg|png|gif|zip)/i

      def force_https?
        true
      end

      def domains
        ["pixiv.net", "pximg.net"]
      end

      def parse
        id = id_from_image
        @submission_url = submission_url_from_id(id) if id
      end

      def original_url
        id = id_from_submission
        return submission_url_from_id(id) if id
        @url
      end

      private

      def submission_url_from_id(id)
        "https://www.pixiv.net/artworks/#{id}"
      end

      def id_from_submission
        return nil unless parsed_url&.host == "www.pixiv.net"

        # http://www.pixiv.net/member_illust.php?mode=medium&illust_id=18557054
        # http://www.pixiv.net/member_illust.php?mode=big&illust_id=18557054
        # http://www.pixiv.net/member_illust.php?mode=manga&illust_id=18557054
        # http://www.pixiv.net/member_illust.php?mode=manga_big&illust_id=18557054&page=1
        if parsed_url.path == "/member_illust.php" && parsed_url.query_values.present? && parsed_url.query_values["illust_id"].present?
          id = parsed_url.query_values["illust_id"].to_i
          return id if id > 0

        # http://www.pixiv.net/i/18557054
        # https://www.pixiv.net/en/artworks/80169645
        # https://www.pixiv.net/artworks/80169645
        elsif (match = parsed_url.path.match(%r{\A/(?:i|(?:en/)?artworks)/(?<illust_id>\d+)\z}i))
          id = match[:illust_id].to_i
          return id if id > 0
        end

        nil
      end

      def id_from_image
        return nil unless parsed_url&.host

        # http://img18.pixiv.net/img/evazion/14901720.png
        # http://i2.pixiv.net/img18/img/evazion/14901720.png
        # http://i2.pixiv.net/img18/img/evazion/14901720_m.png
        # http://i2.pixiv.net/img18/img/evazion/14901720_s.png
        # http://i1.pixiv.net/img07/img/pasirism/18557054_p1.png
        # http://i1.pixiv.net/img07/img/pasirism/18557054_big_p1.png
        if (parsed_url.host =~ /\A(?:i\d+|img\d+)\.pixiv\.net\z/i &&
            (match = parsed_url.path.match(%r{\A(?:/img\d+)?/img/#{MONIKER}/(?<id>\d+)(?:_\w+)?#{EXT}}i))) ||
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
           (parsed_url.host =~ /\A(?:i\.pximg\.net|i\d+\.pixiv\.net)\z/i &&
            (match = parsed_url.path.match(%r{\A(/c/\w+)?/img-[a-z-]+/img/#{DATE}/(?<id>\d+)(?:_\w+)?#{EXT}}i)))
          id = match[:id].to_i
          return id if id > 0
        end

        nil
      end
    end
  end
end
