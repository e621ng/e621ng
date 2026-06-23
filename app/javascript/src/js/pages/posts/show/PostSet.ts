import E621Type from "@/interfaces/E621";
import Dialog from "@/utility/dialog";
import LStorage from "@/utility/storage/Local";
import TaskQueue from "@/utility/TaskQueue";
import { Toast } from "@/utility/Toast";

declare const E621: E621Type;

export default class PostSet {

  private static postUpdateToast: Toast | null = null;

  private static addPostTimeout: number | null = null;
  private static addPostCache: Record<number, Set<number>> = {};

  /**
   * Add the specified post to the set.
   * Individual requests are grouped together to reduce the number of requests.
   * @param {number} set_id Set ID
   * @param {number} post_id Post ID
   */
  static add_post (set_id: number, post_id: number) {
    if (!set_id) return E621.Toast.alert("Error: No set specified");

    if (!this.postUpdateToast)
      this.postUpdateToast = E621.Toast.create("Updating posts...", { timeout: 0 });

    let cache = this.addPostCache[set_id];
    if (!cache) {
      cache = new Set();
      this.addPostCache[set_id] = cache;
    }
    cache.add(post_id);
    this.postUpdateToast.message = `Updating posts (${cache.size} pending)`;

    // Queue up the request
    if (this.addPostTimeout) window.clearTimeout(this.addPostTimeout);
    this.addPostTimeout = window.setTimeout(() => {
      for (const [setID, [...posts]] of Object.entries(this.addPostCache)) {
        PostSet.add_many_posts(Number(setID), posts);
        delete this.addPostCache[setID];
      }
      this.addPostTimeout = null;
    }, 1000);
  }

  /**
   * Adds the specified posts to the set
   * @param {number} set_id Set ID
   * @param {number[]} posts Array of post IDs
   */
  static add_many_posts (set_id: number, posts: number[] = []) {
    if (!set_id) return E621.Toast.alert("Error: No set specified");
    if (typeof set_id !== "number") return E621.Toast.alert("Error: Invalid set specified");

    TaskQueue.add(() => {
      $.ajax({
        type: "POST",
        url: "/post_sets/" + set_id + "/add_posts.json",
        data: {post_ids: posts},
      }).fail((response) => {
        const data = response.responseJSON;
        const errors = $.map(data.errors, (msg) => msg).join("; "),
          message = data.message;
        E621.Toast.alert("Error: " + (message || errors || `${response.status} ${response.statusText}`));
        this.postUpdateToast?.dismiss(true);
        this.postUpdateToast = null;
      }).done(() => {
        if (!this.postUpdateToast) this.postUpdateToast = E621.Toast.create("Updating posts...", { timeout: 0 });
        this.postUpdateToast.message = `Added ${posts.length > 1 ? (posts.length + " posts") : "post"} to <a href="/post_sets/${set_id}">set #${set_id}</a>`;
        this.postUpdateToast.timeout = 3;
        this.postUpdateToast = null;
      });
    }, { name: "PostSet.add_many_posts" });
  }


  private static removePostTimeout: number | null = null;
  private static removePostCache: Record<number, Set<number>> = {};

  /**
   * Remove the specified post from the set.
   * Individual requests are grouped together to reduce the number of requests.
   * @param {number} set_id Set ID
   * @param {number} post_id Post ID
   */
  static remove_post (set_id: number, post_id: number) {
    if (!set_id) return E621.Toast.alert("Error: No set specified");

    if (!this.postUpdateToast)
      this.postUpdateToast = E621.Toast.create("Updating posts...", { timeout: 0 });

    let cache = this.removePostCache[set_id];
    if (!cache) {
      cache = new Set();
      this.removePostCache[set_id] = cache;
    }
    cache.add(post_id);
    this.postUpdateToast.message = `Updating posts (${cache.size} pending)`;

    // Queue up the request
    if (this.removePostTimeout) window.clearTimeout(this.removePostTimeout);
    this.removePostTimeout = window.setTimeout(() => {
      for (const [setID, posts] of Object.entries(this.removePostCache)) {
        PostSet.remove_many_posts(Number(setID), [...posts]);
        delete this.removePostCache[setID];
      }
      this.removePostTimeout = null;
    }, 1000);
  }

  /**
   * Remove the specified posts from the set
   * @param {number} set_id Set ID
   * @param {number[]} posts Array of post IDs
   */
  static remove_many_posts (set_id: number, posts: number[] = []) {
    if (!set_id) return E621.Toast.alert("Error: No set specified");
    if (typeof set_id !== "number") return E621.Toast.alert("Error: Invalid set specified");

    TaskQueue.add(() => {
      $.ajax({
        type: "POST",
        url: "/post_sets/" + set_id + "/remove_posts.json",
        data: { post_ids: posts },
      }).fail((response) => {
        const data = response.responseJSON;
        const errors = $.map(data.errors, (msg) => msg).join("; "),
          message = data.message;
        E621.Toast.alert("Error: " + (message || errors || `${response.status} ${response.statusText}`));
        this.postUpdateToast?.dismiss(true);
        this.postUpdateToast = null;
      }).done(() => {
        if (!this.postUpdateToast) this.postUpdateToast = E621.Toast.create("Updating posts...", { timeout: 0 });
        this.postUpdateToast.message = `Removed ${posts.length > 1 ? (posts.length + " posts") : "post"} from <a href="/post_sets/${set_id}">set #${set_id}</a>`;
        this.postUpdateToast.timeout = 3;
        this.postUpdateToast = null;
      });
    }, { name: "PostSet.remove_many_posts" });
  }

  static initialize_add_to_set_link () {

    let postSetDialog: Dialog | null = null;
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
      PostSet.add_many_posts(Number($("#add-to-set-id").val()), [post_id]);
      postSetDialog.close();
    });
  }

  static update_sets_menu () {
    const target = $("#add-to-set-id") as JQuery<HTMLSelectElement>;
    target.empty();
    target.append($("<option>").text("Loading..."));
    target.off("change");
    TaskQueue.add(() => {
      $.ajax({
        type: "GET",
        url: "/post_sets/for_select.json",
      }).fail(function (data) {
        E621.Toast.alert("Error getting sets list: " + data["message"]);
      }).done(function (data) {
        target.on("change", function (e) {
          const value = Number(e.target.value);
          if (isNaN(value)) {
            E621.Toast.alert("Error: Invalid set specified");
            return;
          }
          LStorage.Posts.Set = value;
        });
        const target_set = LStorage.Posts.Set;
        target.empty();
        ["Owned", "Maintained"].forEach(function (v) {
          const group = $("<optgroup>", {label: v});
          data[v].forEach(function (gi) {
            group.append($("<option>", {value: gi[1], selected: (gi[1] == target_set)}).text(gi[0]));
          });
          target.append(group);
        });
      });
    }, { name: "PostSet.update_sets_menu" });
  }

  static initialize_remove_from_set_links () {
    $("a.set-nav-remove-link").on("click", (event) => {
      event.preventDefault();
      const target = $(event.currentTarget);

      const setID = target.data("setId");
      const postID = target.data("postId");

      PostSet.remove_post(setID, postID);
    });
  }
}
