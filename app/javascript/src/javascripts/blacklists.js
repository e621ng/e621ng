import Utility from './utility'
import LS from './local_storage'

let Blacklist = {};

Blacklist.entries = [];

Blacklist.parse_entry = function (string) {
  const entry = {
    "tags": string,
    "require": [],
    "exclude": [],
    "optional": [],
    "disabled": false,
    "hits": 0,
    "min_score": null
  };
  const matches = string.match(/\S+/g) || [];
  for (const tag of matches) {
    if (tag.charAt(0) === '-') {
      entry.exclude.push(tag.slice(1));
    } else if (tag.charAt(0) === '~') {
      entry.optional.push(tag.slice(1));
    } else if (tag.match(/^score:<.+/)) {
      const score = tag.match(/^score:<(.+)/)[1];
      entry.min_score = parseInt(score);
    } else {
      entry.require.push(tag);
    }
  }
  return entry;
};

Blacklist.parse_entries = function () {
  Blacklist.entries = [];
  let entries = JSON.parse(Utility.meta("blacklisted-tags") || "[]");
  entries = entries.map(e => e.replace(/(rating:[qes])\w+/ig, "$1").toLowerCase());
  entries = entries.filter(e => e.trim() !== "");

  for (const tags of entries) {
    const entry = Blacklist.parse_entry(tags);
    Blacklist.entries.push(entry);
  }
};

Blacklist.entryToggle = function (e) {
  e.preventDefault();
  const tags = $(e.target).text();
  const entry = $.grep(Blacklist.entries, function (e, i) {
    return e.tags === tags;
  })[0];
  if (!entry)
    return;
  entry.disabled = !entry.disabled;
  Blacklist.apply();
  Blacklist.updateSidebarEntry(entry);
};

Blacklist.postSaveReplaceSrc = function (post) {
  const img = post.children("img")[0];
  if (!img)
    return;
  const $img = $(img);
  if (!$img.attr('data-orig-url'))
    $img.attr("data-orig-url", $img.attr('src'));

  if (post.attr('id') === 'image-container' || post.hasClass('post-thumbnail'))
    $img.attr('src', '/images/blacklisted-preview.png');
};

Blacklist.postRestoreSrc = function (post) {
  const img = post.children("img")[0];
  if (!img)
    return;
  const $img = $(img);
  if (!$img.attr('data-orig-url'))
    return;
  $img.attr('src', $img.attr('data-orig-url'));
  $img.attr('data-orig-url', null);
};

Blacklist.postHide = function (post) {
  const $post = $(post);
  $post.addClass("blacklisted").addClass("blacklisted-active");
  Blacklist.postSaveReplaceSrc($post);

  const $video = $post.find("video").get(0);
  if ($video) {
    $video.pause();
    $video.currentTime = 0;
  }
};

Blacklist.postShow = function (post) {
  const $post = $(post);
  $post.addClass("blacklisted").removeClass("blacklisted-active");
  Blacklist.postRestoreSrc(post);
};

Blacklist.updateSidebarEntry = function (entry) {
  const link = $(`.blacklist-toggle-link[title="${entry.tags}"]`);
  if (entry.disabled) {
    link.addClass("blacklist-disabled");
  } else {
    link.removeClass("blacklist-disabled");
  }
};

Blacklist.update_sidebar = function () {
  $("#blacklist-list").html("");
  for (const entry of this.entries) {
    if (entry.hits === 0) {
      return;
    }

    const item = $("<li/>");
    const link = $("<a/>");
    const count = $("<span/>");

    link.text(entry.tags);
    link.addClass("blacklist-toggle-link");
    if (entry.disabled) {
      link.addClass("blacklisted-active");
    }
    link.attr("href", `/posts?tags=${encodeURIComponent(entry.tags)}`);
    link.attr("title", entry.tags);
    link.attr("rel", "nofollow");
    link.on("click.danbooru", Blacklist.entryToggle);
    count.html(entry.hits);
    count.addClass("count");
    item.append(link);
    item.append(" ");
    item.append(count);

    $("#blacklist-list").append(item);
  }

  $("#blacklist-box").show();
}

Blacklist.initialize_disable_all_blacklists = function () {
  if (LS.get("dab") === "1") {
    $("#re-enable-all-blacklists").show();
    for (const entry of Blacklist.entries) {
      entry.disabled = true;
    }
    Blacklist.apply();
  } else {
    $("#disable-all-blacklists").show()
  }

  $("#disable-all-blacklists").on("click.danbooru", function (e) {
    $("#disable-all-blacklists").hide();
    $("#re-enable-all-blacklists").show();
    LS.put("dab", "1");
    for (const entry of Blacklist.entries) {
      entry.disabled = true;
    }
    Blacklist.apply();
    e.preventDefault();
  });

  $("#re-enable-all-blacklists").on("click.danbooru", function (e) {
    $("#disable-all-blacklists").show();
    $("#re-enable-all-blacklists").hide();
    LS.put("dab", "0");
    for (const entry of Blacklist.entries) {
      entry.disabled = false;
    }
    Blacklist.apply();
    e.preventDefault();
  });
}

Blacklist.apply = function () {
  for (const entry of this.entries) {
    entry.hits = 0;
  }

  for (const post of this.posts()) {
    let post_count = 0;
    for (const entry of Blacklist.entries) {
      if (Blacklist.post_match(post, entry)) {
        entry.hits += 1;
        if (!entry.disabled)
          post_count += 1;
      }
    }
    const $post = $(post);
    if (post_count > 0) {
      Blacklist.postHide($post);
    } else {
      Blacklist.postShow($post);
    }
  }

  Blacklist.update_sidebar();
}

Blacklist.posts = function () {
  return $(".post-preview, #image-container, #c-comments .post, .mod-queue-preview.post-preview, .post-thumbnail");
}

Blacklist.post_match = function (post, entry) {
  const $post = $(post);
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

Blacklist.initialize_all = function () {
  Blacklist.parse_entries();

  Blacklist.apply();
  Blacklist.initialize_disable_all_blacklists();
  $("#blacklisted-hider").remove();
}

Blacklist.initialize_anonymous_blacklist = function () {
  if ($(document.body).data('user-is-anonymous') !== true)
    return;

  const anonBlacklist = LS.get('anonymous-blacklist');

  if (anonBlacklist)
    $("meta[name=blacklisted-tags]").attr("content", anonBlacklist);

  $("#anonymous-blacklist-dialog").dialog({autoOpen: false});

  $("#anonymous-blacklist-cancel").on('click', function () {
    $("#anonymous-blacklist-dialog").dialog('close');
  });

  $("#anonymous-blacklist-save").on('click', function () {
    LS.put('anonymous-blacklist', JSON.stringify($("#anonymous-blacklist-edit").val().split(/\n\r?/)));
    $("#anonymous-blacklist-dialog").dialog('close');
    $("meta[name=blacklisted-tags]").attr("content", LS.get('anonymous-blacklist'));
    Blacklist.initialize_all();
  });

  $("#anonymous-blacklist-link").on('click', function () {
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
