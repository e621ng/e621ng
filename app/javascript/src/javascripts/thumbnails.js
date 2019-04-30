import Blacklist from './blacklists';

const Thumbnails = {};

Thumbnails.initialize = function () {
  const postsData = window.___deferred_posts || {};
  const posts = $('.post-thumb.placeholder');
  $.each(posts, function (i, post) {
    const p = $(post);
    const postID = p.data('id');
    if (!postID) {
      p.empty();
      return;
    }
    const postData = postsData[postID];
    if (!postData) {
      p.empty();
      return;
    }
    let blacklist_hit_count = 0;
    $.each(Blacklist.entries, function (j, entry) {
      if (Blacklist.post_match_object(postData, entry)) {
        entry.hits += 1;
        blacklist_hit_count += 1;
      }
    });
    const blacklisted = blacklist_hit_count > 0;
    for (const key in postData) {
      p.data(key.replace(/_/g, '-'), postData[key]);
    }
    p.attr('class', blacklisted ? "post-thumbnail blacklisted blacklisted-active" : "post-thumbnail");
    const img = $('<img>');
    img.attr('src', postData.preview_url);
    img.attr({height: 100, width: 100, title: postData.tags, alt: postData.tags, class: 'post-thumbnail-img'});
    const link = $('<a>');
    link.attr('href', `/posts/${postData.id}`);
    link.append(img);
    p.empty().append(link);
  });
};

$(document).ready(function () {
  Thumbnails.initialize();
});

export default Thumbnails;