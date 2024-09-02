import {SendQueue} from "./send_queue";
import LStorage from "./utility/storage";

let PostSet = {};

PostSet.dialog_setup = false;

let addPostTimeout = null;
const addPostCache = {};

/**
 * Add the specified post to the set.
 * Individual requests are grouped together to reduce the number of requests.
 * @param {number} set_id Set ID
 * @param {number} post_id Post ID
 * @param {boolean} silent Set to true to avoid sending an alert for every request
 */
PostSet.add_post = function (set_id, post_id) {
  if (!set_id) {
    $(window).trigger("danbooru:error", "Error: No set specified");
    return;
  }

  let cache = addPostCache[set_id];
  if (!cache) {
    cache = new Set();
    addPostCache[set_id] = cache;
  }
  cache.add(post_id);
  $(window).trigger("danbooru:notice", `Updating posts (${cache.size} pending)`);

  // Queue up the request
  if (addPostTimeout) window.clearTimeout(addPostTimeout);
  addPostTimeout = window.setTimeout(() => {
    for (const [setID, [...posts]] of Object.entries(addPostCache)) {
      PostSet.add_many_posts(setID, posts);
      delete addPostCache[setID];
    }
    addPostTimeout = null;
  }, 1000);
};

/**
 * Adds the specified posts to the set
 * @param {number} set_id Set ID
 * @param {number[]} posts Array of post IDs
 */
PostSet.add_many_posts = function (set_id, posts = []) {
  if (!set_id) {
    $(window).trigger("danbooru:error", "Error: No set specified");
    return;
  }

  SendQueue.add(function () {
    $.ajax({
      type: "POST",
      url: "/post_sets/" + set_id + "/add_posts.json",
      data: {post_ids: posts},
    }).fail(function (data) {
      console.log(data, data.responseJSON, data.responseJSON.error);
      var message = $.map(data.responseJSON.errors, (msg) => msg).join("; ");
      $(window).trigger("danbooru:error", "Error: " + message);
    }).done(function () {
      $(window).trigger("danbooru:notice", `Added ${posts.length > 1 ? (posts.length + " posts") : "post"} to <a href="/post_sets/${set_id}">set #${set_id}</a>`);
    });
  });
};


let removePostTimeout = null;
const removePostCache = {};

/**
 * Remove the specified post from the set.
 * Individual requests are grouped together to reduce the number of requests.
 * @param {number} set_id Set ID
 * @param {number} post_id Post ID
 * @param {boolean} silent Set to true to avoid sending an alert for every request
 */
PostSet.remove_post = function (set_id, post_id) {
  if (!set_id) {
    $(window).trigger("danbooru:error", "Error: No set specified");
    return;
  }

  let cache = removePostCache[set_id];
  if (!cache) {
    cache = new Set();
    removePostCache[set_id] = cache;
  }
  cache.add(post_id);
  $(window).trigger("danbooru:notice", `Updating posts (${cache.size} pending)`);

  // Queue up the request
  if (removePostTimeout) window.clearTimeout(removePostTimeout);
  removePostTimeout = window.setTimeout(() => {
    for (const [setID, posts] of Object.entries(removePostCache)) {
      PostSet.remove_many_posts(setID, [...posts]);
      delete removePostCache[setID];
    }
    removePostTimeout = null;
  }, 1000);
};

/**
 * Remove the specified posts from the set
 * @param {number} set_id Set ID
 * @param {number[]} posts Array of post IDs
 */
PostSet.remove_many_posts = function (set_id, posts = []) {
  if (!set_id) {
    $(window).trigger("danbooru:error", "Error: No set specified");
    return;
  }

  SendQueue.add(function () {
    $.ajax({
      type: "POST",
      url: "/post_sets/" + set_id + "/remove_posts.json",
      data: { post_ids: posts },
    }).fail(function (data) {
      console.log(data, data.responseJSON, data.responseJSON.error);
      var message = $.map(data.responseJSON.errors, (msg) => msg).join("; ");
      $(window).trigger("danbooru:error", "Error: " + message);
    }).done(function () {
      $(window).trigger("danbooru:notice", `Removed ${posts.length > 1 ? (posts.length + " posts") : "post"} from <a href="/post_sets/${set_id}">set #${set_id}</a>`);
    });
  });
};

PostSet.initialize_add_to_set_link = function () {
  $("#set").on("click.danbooru", function (e) {
    if (!PostSet.dialog_setup) {
      $("#add-to-set-dialog").dialog({autoOpen: false});
      PostSet.dialog_setup = true;
    }
    e.preventDefault();
    PostSet.update_sets_menu();
    $("#add-to-set-dialog").dialog("open");
  });

  $("#add-to-set-submit").on("click", function (e) {
    e.preventDefault();
    const post_id = $("#image-container").data("id");
    PostSet.add_many_posts($("#add-to-set-id").val(), [post_id]);
    $("#add-to-set-dialog").dialog("close");
  });
};

PostSet.update_sets_menu = function () {
  const target = $("#add-to-set-id");
  target.empty();
  target.append($("<option>").text("Loading..."));
  target.off("change");
  SendQueue.add(function () {
    $.ajax({
      type: "GET",
      url: "/post_sets/for_select.json",
    }).fail(function (data) {
      $(window).trigger("danbooru:error", "Error getting sets list: " + data.message);
    }).done(function (data) {
      target.on("change", function (e) {
        LStorage.Posts.Set = e.target.value;
      });
      const target_set = LStorage.Posts.Set;
      target.empty();
      ["Owned", "Maintained"].forEach(function (v) {
        let group = $("<optgroup>", {label: v});
        data[v].forEach(function (gi) {
          group.append($("<option>", {value: gi[1], selected: (gi[1] == target_set)}).text(gi[0]));
        });
        target.append(group);
      });
    });
  });
};

$(function () {
  if ($("#c-posts").length && $("#a-show").length) {
    PostSet.initialize_add_to_set_link();
  }
});

export default PostSet;
