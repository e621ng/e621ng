import Utility from './utility'
import LS from './local_storage'

let Blacklist = {};

Blacklist.entries = [];

Blacklist.parse_entry = function (string) {
  var entry = {
    "tags": string,
    "require": [],
    "exclude": [],
    "optional": [],
    "disabled": false,
    "hits": 0,
    "min_score": null
  };
  var matches = string.match(/\S+/g) || [];
  $.each(matches, function (i, tag) {
    if (tag.charAt(0) === '-') {
      entry.exclude.push(tag.slice(1));
    } else if (tag.charAt(0) === '~') {
      entry.optional.push(tag.slice(1));
    } else if (tag.match(/^score:<.+/)) {
      var score = tag.match(/^score:<(.+)/)[1];
      entry.min_score = parseInt(score);
    } else {
      entry.require.push(tag);
    }
  });
  return entry;
}

Blacklist.parse_entries = function () {
  Blacklist.entries = [];
  let entries = JSON.parse(Utility.meta("blacklisted-tags") || "[]");
  entries = entries.map(e => e.replace(/(rating:[qes])\w+/ig, "$1").toLowerCase());
  entries = entries.filter(e => e.trim() !== "");

  $.each(entries, function (i, tags) {
    const entry = Blacklist.parse_entry(tags);
    Blacklist.entries.push(entry);
  });
}

Blacklist.toggle_entry = function (e) {
  var tags = $(e.target).text();
  var match = $.grep(Blacklist.entries, function (entry, i) {
    return entry.tags === tags;
  })[0];
  if (match) {
    match.disabled = !match.disabled;
    if (match.disabled) {
      Blacklist.post_hide(e.target);
    } else {
      Blacklist.post_unhide(e.target);
    }
  }
  Blacklist.apply();
  e.preventDefault();
}

Blacklist.update_sidebar = function () {
  $("#blacklist-list").html("");
  $.each(this.entries, function (i, entry) {
    if (entry.hits === 0) {
      return;
    }

    var item = $("<li/>");
    var link = $("<a/>");
    var count = $("<span/>");

    link.text(entry.tags);
    link.attr("href", `/posts?tags=${encodeURIComponent(entry.tags)}`);
    link.attr("title", entry.tags);
    link.on("click.danbooru", Blacklist.toggle_entry);
    count.html(entry.hits);
    count.addClass("count");
    item.append(link);
    item.append(" ");
    item.append(count);

    $("#blacklist-list").append(item);
  });

  $("#blacklist-box").show();
}

Blacklist.initialize_disable_all_blacklists = function () {
  if (LS.get("dab") === "1") {
    $("#re-enable-all-blacklists").show();
    $("#blacklist-list a:not(.blacklisted-active)").click();
    Blacklist.apply();
  } else {
    $("#disable-all-blacklists").show()
  }

  $("#disable-all-blacklists").on("click.danbooru", function (e) {
    $("#disable-all-blacklists").hide();
    $("#re-enable-all-blacklists").show();
    LS.put("dab", "1");
    $("#blacklist-list a:not(.blacklisted-active)").click();
    e.preventDefault();
  });

  $("#re-enable-all-blacklists").on("click.danbooru", function (e) {
    $("#disable-all-blacklists").show();
    $("#re-enable-all-blacklists").hide();
    LS.put("dab", "0");
    $("#blacklist-list a.blacklisted-active").click();
    e.preventDefault();
  });
}

Blacklist.apply = function () {
  $.each(this.entries, function (i, entry) {
    entry.hits = 0;
  });

  var count = 0

  $.each(this.posts(), function (i, post) {
    var post_count = 0;
    $.each(Blacklist.entries, function (j, entry) {
      if (Blacklist.post_match(post, entry)) {
        entry.hits += 1;
        count += 1;
        post_count += 1;
      }
    });
    if (post_count > 0) {
      Blacklist.post_hide(post);
    } else {
      Blacklist.post_unhide(post);
    }
  });

  return count;
}

Blacklist.posts = function () {
  return $(".post-preview, #image-container, #c-comments .post, .mod-queue-preview.post-preview, .post-thumbnail");
}

Blacklist.post_match = function (post, entry) {
  if (entry.disabled) {
    return false;
  }

  var $post = $(post);
  if ($post.hasClass('post-no-blacklist'))
    return false;
  let post_data = {
    id: $post.data('id'),
    score: parseInt($post.data('score'), 10),
    tags: $post.data('tags'),
    rating: $post.data('rating'),
    uploader_id: $post.data('uploader-id'),
    user: $post.data('uploader').toLowerCase(),
    flags: $post.data('flags')
  };
  return Blacklist.post_match_object(post_data, entry);
};

Blacklist.post_match_object = function (post, entry) {
  if (entry.disabled)
    return false;

  const score_test = entry.min_score === null || post.score < entry.min_score;
  const tags = post.tags.match(/\S+/g) || [];
  tags.push(`id:${post.id}`);
  tags.push(`rating:${post.rating}`);
  tags.push(`uploaderid:${post.uploader_id}`);
  tags.push(`user:${post.user}`);
  tags.push(`height:${post.height}`);
  tags.push(`width:${post.width}`);
  $.each(post.flags.match(/\S+/g) || [], function (i, v) {
    tags.push(`status:${v}`);
  });

  return (Utility.is_subset(tags, entry.require) && score_test)
    && (!entry.optional.length || Utility.intersect(tags, entry.optional).length)
    && !Utility.intersect(tags, entry.exclude).length;
}

Blacklist.post_hide = function (post) {
  var $post = $(post);
  $post.addClass("blacklisted").addClass("blacklisted-active");

  var $video = $post.find("video").get(0);
  if ($video) {
    $video.pause();
    $video.currentTime = 0;
  }
}

Blacklist.post_unhide = function (post) {
  var $post = $(post);
  $post.addClass("blacklisted").removeClass("blacklisted-active");
}

Blacklist.initialize_all = function () {
  Blacklist.parse_entries();

  if (Blacklist.apply() > 0) {
    Blacklist.update_sidebar();
    Blacklist.initialize_disable_all_blacklists();
  }
  $("#blacklisted-hider").remove();
}

Blacklist.initialize_anonymous_blacklist = function() {
  if($(document.body).data('user-is-anonymous') !== true)
    return;

  const anonBlacklist = LS.get('anonymous-blacklist');

  if(anonBlacklist)
    $("meta[name=blacklisted-tags]").attr("content", anonBlacklist);

  $("#anonymous-blacklist-dialog").dialog({autoOpen: false});

  $("#anonymous-blacklist-cancel").on('click', function() {
    $("#anonymous-blacklist-dialog").dialog('close');
  });

  $("#anonymous-blacklist-save").on('click', function() {
    LS.put('anonymous-blacklist', JSON.stringify($("#anonymous-blacklist-edit").val().split(/\n\r?/)));
    $("#anonymous-blacklist-dialog").dialog('close');
    $("meta[name=blacklisted-tags]").attr("content", LS.get('anonymous-blacklist'));
    Blacklist.initialize_all();
  });

  $("#anonymous-blacklist-link").on('click', function() {
    let entries = JSON.parse(Utility.meta("blacklisted-tags") || "[]");
    entries = entries.map(e => e.replace(/(rating:[qes])\w+/ig, "$1").toLowerCase());
    entries = entries.filter(e => e.trim() !== "");
    $("#anonymous-blacklist-edit").val(entries.join('\n'));
    $("#anonymous-blacklist-dialog").dialog('open');
  });
};

$(document).ready(function () {
  // if ($("#blacklist-box").length === 0) {
  //   return;
  // }

  Blacklist.initialize_anonymous_blacklist();
  Blacklist.initialize_all();
});

export default Blacklist
