import LStorage from "../utility/storage";
import Blacklist from "../blacklists";
import PostCache from "./PostCache";

export default class User {

  static _userData = null;

  static _authToken = null;

  static _init () {

    // Load from metatags
    const metaRaw = $("meta");
    let allowedMeta = [ "user-comment-threshold", "blacklisted-tags", "blacklist-users", "default-image-size", "csrf-token" ];
    const meta = {};
    for (const one of metaRaw) {
      if (!allowedMeta.includes(one.name)) continue;
      meta[one.name] = one.content;
    }


    // Parse metatag data
    if (!meta["user-comment-threshold"]) meta["user-comment-threshold"] = -10;
    else meta["user-comment-threshold"] = parseInt(meta["user-comment-threshold"]);

    if (!meta["blacklisted-tags"]) meta["blacklisted-tags"] = [];
    else {
      try {
        meta["blacklisted-tags"] = JSON.parse(meta["blacklisted-tags"]);
      } catch { meta["blacklisted-tags"] = []; }
    }

    if (!meta["blacklist-users"]) meta["blacklist-users"] = false;
    else meta["blacklist-users"] = meta["blacklist-users"] === "true";

    if (!meta["default-image-size"]) meta["default-image-size"] = "large";
    this._authToken = meta["csrf-token"] || null;


    // Load from body
    const data = document.body.dataset;
    this._userData = {
      id: data.userId ? parseInt(data.userId) : 0,
      name: data.userName,
      level: data.userLevel,
      levelString: data.userLevelString,
      commentThreshold: meta["user-comment-threshold"] || -10,

      blacklist: {
        tags: meta["blacklisted-tags"],
        users: meta["blacklist-users"],
      },

      posts: {
        perPage: data.userPerPage,
        defaultImageSize: meta["default-image-size"],
      },

      can: {
        approvePosts: data.userCanApprovePosts === "true",
        uploadFree: data.userCanUploadFree === "true",
      },

      is: {
        anonymous: data.userIsAnonymous === "true",
        blocked: data.userIsBlocked === "true",

        member: data.userIsMember === "true",
        privileged: data.userIsPrivileged === "true",
        formerStaff: data.userIsFormerStaff === "true",

        janitor: data.userIsJanitor === "true",
        moderator: data.userIsModerator === "true",
        admin: data.userIsAdmin === "true",
      },
    };

    // Load anonymous blacklist
    if (this._userData.is.anonymous) {
      try {
        this._userData.blacklist.tags = JSON.parse(LStorage.Blacklist.AnonymousBlacklist);
      } catch { this._userData.blacklist.tags = []; }

      $("<meta>")
        .attr({
          name: "blacklisted-tags",
          content: JSON.stringify(this._userData.blacklist.tags),
        })
        .appendTo("head");
    }
  }

  static _get () {
    if (!this._userData) this._init();
    return this._userData;
  }

  /** @returns {number} User ID */
  static get id () { return this._get().id; }

  /** @returns {string} User name */
  static get name () { return this._get().name; }

  /** @returns {number} User level ID */
  static get level () { return this._get().level; }

  /** @returns {number} User level */
  static get levelString () { return this._get().levelString; }

  /** @returns {number} Maximum comment score before it is filtered out */
  static get commentThreshold () { return this._get().commentThreshold; }

  /** @returns {{tags: string[], users: boolean}} Blacklist data */
  static get blacklist () { return this._get().blacklist; }

  /** @returns {object} */
  static get posts () { return this._get().posts; }

  /** @returns {object} */
  static get can () { return this._get().can; }

  /** @returns {object} */
  static get is () { return this._get().is; }

  static async addBlacklistedTag (tag) {
    if (this.blacklist.tags.includes(tag)) return;
    this.blacklist.tags.push(tag);

    return this.saveBlacklist();
  }

  static async removeBlacklistedTag (tag) {
    if (!this.blacklist.tags.includes(tag)) return;
    this.blacklist.tags = this.blacklist.tags.filter(n => n !== tag);

    return this.saveBlacklist();
  }

  static async saveBlacklist () {
    return new Promise((resolve, reject) => {
      if (this.is.anonymous) {
        LStorage.Blacklist.AnonymousBlacklist = JSON.stringify(this.blacklist.tags);
        resolve();
        return;
      } else {
        if (!this._authToken) {
          reject("Unable to authorize request");
          return;
        }

        // TODO user anon
        $.ajax(`/users/${this.id}.json`, {
          method: "PUT",
          data: {
            "user[blacklisted_tags]": this.blacklist.tags.join("\n"),
          },
        })
          .done(() => { resolve(); })
          .fail((error) => { reject(error); });
      }
    }).then(
      () => {
        // Reload the dialog editor box
        $("#blacklist-edit-dialog").dialog("close");
        $("meta[name=blacklisted-tags]").attr("content", JSON.stringify(this.blacklist.tags));

        // Rebuild the filters
        Blacklist.regenerate_filters();
        Blacklist.add_posts(PostCache.sample());
        Blacklist.update_visibility();

        return Promise.resolve();
      },
      (error) => {
        Danbooru.error(error);
        return Promise.reject();
      },
    );
  }
}
