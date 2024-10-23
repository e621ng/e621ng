import Utility from "./utility";
import LStorage from "./utility/storage";

class Block {
  static entries = JSON.parse(Utility.meta("user-blocks") || "[]");

  static hiddenCount = {
    Blips: 0,
    Comments: 0,
    ForumPosts: 0,
    ForumTopics: 0,
  };

  static nameMap = {
    Blips: "blip",
    Comments: "comment",
    ForumPosts: "forum post",
    ForumTopics: "forum topic",
  };

  static disabled = [];

  static init () {
    this.activateAll();
    for (const type of Object.keys(this.hiddenCount)) {
      const disabled = LStorage.Blocking[`DisableHide${type}`];
      if (disabled) {
        this.deactivateType(type);
      }
    }
  }

  static hide ($selector, name) {
    this.hiddenCount[name] += $selector.length;
    $selector.hide();
  }

  static show ($selector, name) {
    this.hiddenCount[name] -= $selector.length;
    $selector.show();
  }

  static text (name) {
    const n = this.hiddenCount[name];
    return `${n} ${this.nameMap[name]}${n === 1 ? "" : "s"} on this page ${n === 1 ? "was" : "were"} hidden due to a user being blocked.`;
  }

  static updateText () {
    let html = "";
    for (const [name, counts] of Object.entries(this.hiddenCount)) {
      if (counts === 0) {
        if (this.disabled.includes(name)) {
          html += `<p>Hiding of ${this.nameMap[name]}s has been disabled. Click <a href="#" class="reactivate-blocks" data-block-type="${name}">here</a> to reenable blocking.</p>`;
        }
        continue;
      }

      html += `<p>${this.text(name)} Click <a href="#" class="deactivate-blocks" data-block-type="${name}">here</a> to temporarily disable blocking these.</p>`;
    }

    $(".blocked-notice").html(html);
    this.reinitialize_listeners();
  }

  static toggle (id, hide = true) {
    const entry = this.entries.find(e => e.target_id === id);
    if (!entry) {
      return;
    }

    const { hide_blips, hide_comments, hide_forum_topics, hide_forum_posts } = entry;

    if (hide_blips) {
      if (hide) {
        this.hide($(`article.blip[data-creator-id=${entry.target_id}]:visible`), "Blips");
      } else {
        this.show($(`article.blip[data-creator-id=${entry.target_id}]:hidden`), "Blips");
      }
    }

    if (hide_comments) {
      if (hide) {
        this.hide($(`article.comment[data-creator-id=${entry.target_id}]:visible`), "Comments");
      } else {
        this.show($(`article.comment[data-creator-id=${entry.target_id}]:hidden`), "Comments");
      }
    }

    if (hide_forum_topics) {
      if (hide) {
        this.hide($(`tr.forum-topic-row[data-creator-id=${entry.target_id}]:visible`), "ForumTopics");
      } else {
        this.show($(`tr.forum-topic-row[data-creator-id=${entry.target_id}]:hidden`), "ForumTopics");
      }
    }

    if (hide_forum_posts) {
      if (hide) {
        this.hide($(`article.forum-post[data-creator-id=${entry.target_id}]:visible`), "ForumPosts");
      } else {
        this.show($(`article.forum-post[data-creator-id=${entry.target_id}]:hidden`), "ForumPosts");
      }
    }
  }

  static activate (id) { return this.toggle(id, true); }

  static deactivate (id) { return this.toggle(id, false); }

  static activateAll () { return this.entries.map(e => this.activate(e.target_id)); }

  static deactivateAll () { return this.entries.map(e => this.deactivate(e.target_id)); }

  static activateType (name) {
    if (!this.disabled.includes(name)) {
      return;
    }

    const entries = this.entries.filter(e => e[`hide_${this.nameMap[name].replaceAll(" ", "_")}s`] === true);
    entries.forEach(e => this.activate(e.target_id));
    this.disabled.splice(this.disabled.indexOf(name), 1);
    LStorage.Blocking[`DisableHide${name}`] = false;
    this.updateText();
  }

  static deactivateType (name) {
    if (this.disabled.includes(name)) {
      return;
    }

    const entries = this.entries.filter(e => e[`hide_${this.nameMap[name].replaceAll(" ", "_")}s`] === true);
    entries.forEach(e => this.deactivate(e.target_id));
    this.disabled.push(name);
    LStorage.Blocking[`DisableHide${name}`] = true;
    this.updateText();
  }

  static reinitialize_listeners () {
    $(".deactivate-blocks").off("click.e621.block").on("click.e621.block", function (event) {
      event.preventDefault();
      Block.deactivateType($(event.currentTarget).data("block-type"));
    });
    $(".reactivate-blocks").off("click.e621.block").on("click.e621.block", function (event) {
      event.preventDefault();
      Block.activateType($(event.currentTarget).data("block-type"));
    });
  }
}

$(document).ready(function () {
  Block.init();
  Block.updateText();
});

export default Block;
