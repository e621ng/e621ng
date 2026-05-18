import Page from "@/utility/Page";
import LStorage from "@/utility/storage";
import TaskQueue from "@/utility/TaskQueue";
import Dialog from "@/utility/dialog";

let PostSet = {};

let addPostTimeout = null;
let postUpdateToast = null;
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

  if (!postUpdateToast)
    postUpdateToast = E621.Toast.create("Updating posts...", { timeout: 0 });

  let cache = addPostCache[set_id];
  if (!cache) {
    cache = new Set();
    addPostCache[set_id] = cache;
  }
  cache.add(post_id);
  postUpdateToast.message = `Updating posts (${cache.size} pending)`;

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

  TaskQueue.add(() => {
    $.ajax({
      type: "POST",
      url: "/post_sets/" + set_id + "/add_posts.json",
      data: {post_ids: posts},
    }).fail((response) => {
      const data = response.responseJSON;
      const errors = $.map(data.errors, (msg) => msg).join("; "),
        message = data.message;
      E621.Toast.alert("Error: " + (message || errors));
      postUpdateToast?.dismiss(true);
      postUpdateToast = null;
    }).done(() => {
      if (!postUpdateToast) postUpdateToast = E621.Toast.create("Updating posts...", { timeout: 0 });
      postUpdateToast.message = `Added ${posts.length > 1 ? (posts.length + " posts") : "post"} to <a href="/post_sets/${set_id}">set #${set_id}</a>`;
      postUpdateToast.timeout = 3;
      postUpdateToast = null;
    });
  }, { name: "PostSet.add_many_posts" });
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

  if (!postUpdateToast)
    postUpdateToast = E621.Toast.create("Updating posts...", { timeout: 0 });

  let cache = removePostCache[set_id];
  if (!cache) {
    cache = new Set();
    removePostCache[set_id] = cache;
  }
  cache.add(post_id);
  postUpdateToast.message = `Updating posts (${cache.size} pending)`;

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

  TaskQueue.add(() => {
    $.ajax({
      type: "POST",
      url: "/post_sets/" + set_id + "/remove_posts.json",
      data: { post_ids: posts },
    }).fail((response) => {
      const data = response.responseJSON;
      const errors = $.map(data.errors, (msg) => msg).join("; "),
        message = data.message;
      E621.Toast.alert("Error: " + (message || errors));
      postUpdateToast?.dismiss(true);
      postUpdateToast = null;
    }).done(() => {
      if (!postUpdateToast) postUpdateToast = E621.Toast.create("Updating posts...", { timeout: 0 });
      postUpdateToast.message = `Removed ${posts.length > 1 ? (posts.length + " posts") : "post"} from <a href="/post_sets/${set_id}">set #${set_id}</a>`;
      postUpdateToast.timeout = 3;
      postUpdateToast = null;
    });
  }, { name: "PostSet.remove_many_posts" });
};

PostSet.initialize_add_to_set_link = function () {

  let postSetDialog = null;
  $(".add-to-set").on("click.danbooru", function (e) {
    e.preventDefault();

    if (!postSetDialog)
      postSetDialog = new Dialog("#add-to-set-dialog");
    PostSet.update_sets_menu();

    postSetDialog.toggle();
  });

  $("#add-to-set-submit").on("click", function (e) {
    e.preventDefault();
    const post_id = $("#image-container").data("id");
    PostSet.add_many_posts($("#add-to-set-id").val(), [post_id]);
    postSetDialog.close();
  });
};

PostSet.update_sets_menu = function () {
  const target = $("#add-to-set-id");
  target.empty();
  target.append($("<option>").text("Loading..."));
  target.off("change");
  TaskQueue.add(() => {
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
  }, { name: "PostSet.update_sets_menu" });
};

PostSet.initialize_remove_from_set_links = function () {
  $("a.set-nav-remove-link").on("click", (event) => {
    event.preventDefault();
    const target = $(event.currentTarget);

    const setID = target.data("setId");
    const postID = target.data("postId");

    PostSet.remove_post(setID, postID);
  });
};

$(function () {
  if (!Page.matches("posts", "show")) return;
  PostSet.initialize_add_to_set_link();
  PostSet.initialize_remove_from_set_links();
});

export default PostSet;
