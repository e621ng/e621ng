import Utility from './utility'
import LS from './local_storage'

let Blacklist = {};

Blacklist.post_count = 0;

Blacklist.entries = [];

Blacklist.entryGet = function (line) {
  return $.grep(Blacklist.entries, function (e, i) {
    return e.tags === line;
  })[0];
};

Blacklist.entriesAllSet = function (enabled) {
  LS.put("dab", enabled ? "0" : "1");
  for (const entry of Blacklist.entries) {
    entry.disabled = !enabled;
  }
};

Blacklist.lineToggle = function (line) {
  const entry = Blacklist.entryGet(line);
  if (!entry)
    return;
  entry.disabled = !entry.disabled;
};

Blacklist.lineSet = function (line, enabled) {
  const entry = Blacklist.entryGet(line);
  if (!entry)
    return;
  entry.disabled = !enabled;
};

Blacklist.entryParse = function (string) {
  const fixInsanity = function(input) {
    switch(input) {
      case '=>':
        return '>=';
      case '=<':
        return '<=';
      case '=':
        return '==';
      case '':
        return '==';
      default:
        return input;
    }
  };
  const entry = {
    "tags": string,
    "require": [],
    "exclude": [],
    "optional": [],
    "disabled": false,
    "hits": 0,
    "score_comparison": null,
    "username": false,
    "user_id": 0
  };
  const matches = string.match(/\S+/g) || [];
  for (const tag of matches) {
    if (tag.charAt(0) === '-') {
      entry.exclude.push(tag.slice(1));
    } else if (tag.charAt(0) === '~') {
      entry.optional.push(tag.slice(1));
    } else if (tag.match(/^score:[<=>]{0,2}-?\d+/)) {
      const score = tag.match(/^score:([<=>]{0,2})(-?\d+)/);
      entry.score_comparison = [fixInsanity(score[1]), parseInt(score[2], 10)];
    } else {
      entry.require.push(tag);
    }
  }
  const user_matches = string.match(/user:([\w\d]+)/) || [];
  if (user_matches.length === 2) {
    entry.username = user_matches[1];
  }
  const userid_matches = string.match(/userid:(\d+)/) || [];
  if (userid_matches.length === 2) {
    entry.user_id = parseInt(userid_matches[1], 10);
  }
  return entry;
};

Blacklist.entriesParse = function () {
  Blacklist.entries = [];
  let entries = JSON.parse(Utility.meta("blacklisted-tags") || "[]");
  entries = entries.map(e => e.replace(/(rating:[qes])\w+/ig, "$1").toLowerCase());
  entries = entries.filter(e => e.trim() !== "");

  for (const tags of entries) {
    const entry = Blacklist.entryParse(tags);
    Blacklist.entries.push(entry);
  }
};

Blacklist.domEntryToggle = function (e) {
  e.preventDefault();
  const tags = $(e.target).text();
  Blacklist.lineToggle(tags);
  Blacklist.apply();
};

Blacklist.postSaveReplaceSrcPicture = function (post, picture) {
  const sources = picture.children('source');
  const img = picture.children('img');

  if (!img || !sources || sources.length !== 2)
    return;

  if (!img.attr('data-crop-url'))
    img.attr('data-crop-url', $(sources[0]).attr('srcset'));
  if (!img.attr('data-orig-url'))
    img.attr('data-orig-url', $(sources[1]).attr('srcset'));

  if (post.hasClass('post-thumbnail-blacklisted')) {
    post.removeClass('blacklisted-active');
    img.attr('src', '/images/blacklisted-preview.png');
    $(sources[0]).attr('srcset', '/images/blacklisted-preview.png');
    $(sources[1]).attr('srcset', '/images/blacklisted-preview.png');
  }
};

Blacklist.postRestoreSrcPicture = function (post, picture) {
  const sources = picture.children('source');
  const img = picture.children('img');

  if (!img || !sources || sources.length !== 2)
    return;

  const cropUrl = img.attr('data-crop-url');
  const origUrl = img.attr('data-orig-url');

  if (!cropUrl || !origUrl) {
    return;
  }

  $(sources[0]).attr('srcset', img.attr('data-crop-url'));
  $(sources[1]).attr('srcset', img.attr('data-orig-url'));
  img.attr('src', img.attr('data-orig-url'));
};

Blacklist.postSaveReplaceSrc = function (post) {
  const picture = post.find("picture");
  if (picture.length) {
    Blacklist.postSaveReplaceSrcPicture(post, picture);
    return;
  }

  const img = post.children("img")[0];
  if (!img)
    return;
  const $img = $(img);
  if (!$img.attr('data-orig-url'))
    $img.attr("data-orig-url", $img.attr('src'));

  if (post.attr('id') === 'image-container' || post.hasClass('post-thumbnail') || post.hasClass('post-thumbnail-blacklisted')) {
    $img.attr('src', '/images/blacklisted-preview.png');
    post.removeClass('blacklisted-active').addClass('blacklisted-active-visible');
  }
};

Blacklist.postRestoreSrc = function (post) {
  const picture = post.find("picture");
  if (picture.length) {
    Blacklist.postRestoreSrcPicture(post, picture);
    return;
  }
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
  Blacklist.postRestoreSrc(post);
  $post.addClass("blacklisted").removeClass("blacklisted-active").removeClass("blacklisted-active-visible");
};

Blacklist.sidebarUpdate = function () {
  if (LS.get("dab") === "1") {
    $("#disable-all-blacklists").hide();
    $("#re-enable-all-blacklists").show();
  } else {
    $("#disable-all-blacklists").show();
    $("#re-enable-all-blacklists").hide();
  }
  $("#blacklist-list").html("");
  if (Blacklist.post_count <= 0) {
    $("#blacklist-box").hide();
    return;
  }
  for (const entry of this.entries) {
    if (entry.hits === 0) {
      continue;
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
    link.on("click.danbooru", Blacklist.domEntryToggle);
    count.html(entry.hits);
    count.addClass("post-count");
    item.append(link);
    item.append(" ");
    item.append(count);

    $("#blacklist-list").append(item);
  }
  $("#blacklisted-count").text(`(${Blacklist.post_count})`);


  $("#blacklist-box").show();
}

Blacklist.initialize_disable_all_blacklists = function () {
  if (LS.get("dab") === "1") {
    Blacklist.entriesAllSet(false);
  }

  $("#disable-all-blacklists").on("click.danbooru", function (e) {
    e.preventDefault();
    Blacklist.entriesAllSet(false);
    Blacklist.apply();
  });

  $("#re-enable-all-blacklists").on("click.danbooru", function (e) {
    e.preventDefault();
    Blacklist.entriesAllSet(true);
    Blacklist.apply();
  });
}

Blacklist.apply = function () {
  Blacklist.post_count = 0;
  for (const entry of this.entries) {
    entry.hits = 0;
  }

  for (const post of this.posts()) {
    let post_count = 0;
    for (const entry of Blacklist.entries) {
      if (Blacklist.postMatch(post, entry)) {
        entry.hits += 1;
        if (!entry.disabled)
          post_count += 1;
        Blacklist.post_count += 1;
      }
    }
    const $post = $(post);
    if (post_count > 0) {
      Blacklist.postHide($post);
    } else {
      Blacklist.postShow($post);
    }
  }

  if (Utility.meta("blacklist-users") === "true") {
    for (const entry of this.entries.filter(x => x.username !== false)) {
      $(`article[data-creator="${entry.username}"]`).hide();
    }
    for (const entry of this.entries.filter(x => x.user_id !== 0)) {
      $(`article[data-creator-id="${entry.user_id}"]`).hide();
    }
  }

  Blacklist.sidebarUpdate();
}

Blacklist.posts = function () {
  return $(".post-preview, #image-container, #c-comments .post, .mod-queue-preview.post-preview, .post-thumbnail");
}

Blacklist.postMatch = function (post, entry) {
  const $post = $(post);
  if ($post.hasClass('post-no-blacklist'))
    return false;
  let post_data = {
    id: $post.data('id'),
    score: parseInt($post.data('score'), 10),
    tags: $post.data('tags'),
    rating: $post.data('rating'),
    uploader_id: $post.data('uploader-id'),
    user: $post.data('uploader').toString().toLowerCase(),
    flags: $post.data('flags'),
    is_fav: $post.data('is-favorited')
  };
  return Blacklist.postMatchObject(post_data, entry);
};

Blacklist.postMatchObject = function (post, entry) {
  const rangeComparator = function (comparison, target) {
    // Bad comparison, post matches score.
    if (!Array.isArray(comparison) || typeof target === 'undefined' || comparison.length !== 2)
      return true;
    switch (comparison[0]) {
      case '<':
        return target < comparison[1];
      case '<=':
        return target <= comparison[1];
      case '==':
        return target == comparison[1];
      case '>=':
        return target >= comparison[1];
      case '>':
        return target > comparison[1];
      default:
        return true;
    }
  };
  const score_test = rangeComparator(entry.score_comparison, post.score);
  const tags = post.tags.match(/\S+/g) || [];
  tags.push(`id:${post.id}`);
  tags.push(`rating:${post.rating}`);
  tags.push(`userid:${post.uploader_id}`);
  tags.push(`user:${post.user}`);
  tags.push(`height:${post.height}`);
  tags.push(`width:${post.width}`);
  if(post.is_fav)
    tags.push('fav:me');
  $.each(post.flags.match(/\S+/g) || [], function (i, v) {
    tags.push(`status:${v}`);
  });

  return (Utility.is_subset(tags, entry.require) && score_test)
    && (!entry.optional.length || Utility.intersect(tags, entry.optional).length)
    && !Utility.intersect(tags, entry.exclude).length;
}

Blacklist.initialize_all = function () {
  Blacklist.entriesParse();

  Blacklist.initialize_disable_all_blacklists();
  Blacklist.apply();
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

Blacklist.collapseGet = function () {
  const lsValue = LS.get('bc') || '1';
  return lsValue === '1';
};

Blacklist.collapseSet = function (collapsed) {
  LS.put('bc', collapsed ? "1" : "0");
};

Blacklist.collapseUpdate = function () {
  if (Blacklist.collapseGet()) {
    $('#blacklist-list').hide();
    $('#blacklist-collapse').addClass('hidden');
  } else {
    $('#blacklist-list').show();
    $('#blacklist-collapse').removeClass('hidden');
  }
};

Blacklist.initialize_collapse = function () {
  $("#blacklist-collapse").on('click', function (e) {
    e.preventDefault();
    const current = Blacklist.collapseGet();
    Blacklist.collapseSet(!current);
    Blacklist.collapseUpdate();
  });
  Blacklist.collapseUpdate();
};

$(document).ready(function () {
  Blacklist.initialize_collapse();
  Blacklist.initialize_anonymous_blacklist();
  Blacklist.initialize_all();
});

export default Blacklist
