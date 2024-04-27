# frozen_string_literal: true

# Pixiv
#
# * https://i.pximg.net/img-original/img/2014/10/03/18/10/20/46324488_p0.png
#
# * https://i.pximg.net/c/250x250_80_a2/img-master/img/2014/10/29/09/27/19/46785915_p0_square1200.jpg
# * https://i.pximg.net/img-master/img/2014/10/03/18/10/20/46324488_p0_master1200.jpg
#
# * https://www.pixiv.net/member_illust.php?mode=medium&illust_id=46324488
# * https://www.pixiv.net/member_illust.php?mode=manga&illust_id=46324488
# * https://www.pixiv.net/member_illust.php?mode=manga_big&illust_id=46324488&page=0
#
# * https://www.pixiv.net/member.php?id=339253
# * https://www.pixiv.net/member_illust.php?id=339253&type=illust
# * https://www.pixiv.net/u/9202877
# * https://www.pixiv.net/stacc/noizave
# * http://www.pixiv.me/noizave
#
# Fanbox
#
# * https://fanbox.pixiv.net/images/post/39714/JvjJal8v1yLgc5DPyEI05YpT.png
# * https://pixiv.pximg.net/fanbox/public/images/creator/1566167/profile/Ix6bnJmTaOAFZhXHLbWyIY1e.jpeg
#
# * https://pixiv.pximg.net/c/400x400_90_a2_g5/fanbox/public/images/creator/1566167/profile/Ix6bnJmTaOAFZhXHLbWyIY1e.jpeg
# * https://pixiv.pximg.net/c/1200x630_90_a2_g5/fanbox/public/images/post/186919/cover/VCI1Mcs2rbmWPg0mmiTisovn.jpeg
#
# * https://www.pixiv.net/fanbox/creator/1566167/post/39714
# * https://www.pixiv.net/fanbox/creator/1566167
#
# Novels
#
# * https://i.pximg.net/novel-cover-original/img/2019/01/14/01/15/05/10617324_d84daae89092d96bbe66efafec136e42.jpg
# * https://i.pximg.net/c/600x600/novel-cover-master/img/2019/01/14/01/15/05/10617324_d84daae89092d96bbe66efafec136e42_master1200.jpg
# * https://img-novel.pximg.net/img-novel/work_main/XtFbt7gsymsvyaG45lZ8/1554.jpg?20190107110435
#
# * https://www.pixiv.net/novel/show.php?id=10617324
# * https://novel.pixiv.net/works/1554
#
# Sketch
#
# * https://img-sketch.pixiv.net/uploads/medium/file/4463372/8906921629213362989.jpg
# * https://img-sketch.pximg.net/c!/w=540,f=webp:jpeg/uploads/medium/file/4463372/8906921629213362989.jpg
# * https://sketch.pixiv.net/items/1588346448904706151
# * https://sketch.pixiv.net/@0125840
#

module Sources
  module Strategies
    class PixivSlim < Base
      def domains
        ["pixiv.net", "pximg.net"]
      end

      def canonical_url
        image_url
      end

      def image_urls
        [url]
      end

      def headers
        { referer: "https://www.pixiv.net" }
      end
    end
  end
end
