import Blacklist from './blacklists';
import LS from './local_storage';

const Thumbnails = {};

Thumbnails.initialize = function () {
  const clearPlaceholder = function (post) {
    if (post.hasClass('thumb-placeholder-link')) {
      post.removeClass('thumb-placeholder-link');
    } else {
      post.empty();
    }
  };
  const postsData = window.___deferred_posts || {};
  const posts = $('.post-thumb.placeholder, .thumb-placeholder-link');
  const DAB = LS.get("dab") === "1";
  $.each(posts, function (i, post) {
    const p = $(post);
    const postID = p.data('id');
    if (!postID) {
      clearPlaceholder(p);
      return;
    }
    const postData = postsData[postID];
    if (!postData) {
      clearPlaceholder(p);
      return;
    }
    let blacklist_hit_count = 0;
    $.each(Blacklist.entries, function (j, entry) {
      if (Blacklist.postMatchObject(postData, entry)) {
        entry.hits += 1;
        blacklist_hit_count += 1;
      }
    });
    const newTag = $('<div>');
    const blacklisted = DAB ? false : blacklist_hit_count > 0;
    for (const key in postData) {
      newTag.attr("data-" + key.replace(/_/g, '-'), postData[key]);
    }
    newTag.attr('class', blacklisted ? "post-thumbnail blacklisted" : "post-thumbnail");
    if (p.hasClass('thumb-placeholder-link'))
      newTag.addClass('dtext');
    const img = $('<img>');
    img.attr('src', postData.preview_url || '/images/deleted-preview.png');
    img.attr({
      height: postData.preview_url ? postData.preview_height : 150,
      width: postData.preview_url ? postData.preview_width : 150,
      title: `Rating: ${postData.rating}\r\nID: ${postData.id}\r\nStatus: ${postData.status}\r\nDate: ${postData.created_at}\r\n\r\n${postData.tags}`,
      alt: postData.tags,
      class: 'post-thumbnail-img'
    });
    const link = $('<a>');
    link.attr('href', `/posts/${postData.id}`);
    link.append(img);
    newTag.append(link);
    p.replaceWith(newTag);
  });
};

$(document).ready(function () {
  Thumbnails.initialize();
  $(window).on('e621:add_deferred_posts', (_, posts) => {
    window.___deferred_posts = window.___deferred_posts || {}
    window.___deferred_posts = $.extend(window.___deferred_posts, posts);
    Thumbnails.initialize();
  });
  $(document).on('thumbnails:apply', Thumbnails.initialize);
});

export default Thumbnails;
