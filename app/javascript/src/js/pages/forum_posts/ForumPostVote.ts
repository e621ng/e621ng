import User from "@/models/User";
import Flash from "@/utility/Flash";

interface VoteResponse {
  id: number;
  forum_post_id: number;
  creator_id: number;
  creator_name: string;
  score: number;
}

function scoreToStr (score: number): string {
  switch (score) {
    case 1: return "up";
    case 0: return "meh";
    case -1: return "down";
    default: throw new Error(`Unknown score: ${score}`);
  }
}

export default class ForumPostVote {

  private $voteList: JQuery<HTMLElement>;
  private postId: number;

  constructor (element: HTMLElement) {
    this.$voteList = $(element);
    this.postId = parseInt(this.$voteList.data("forum-id"), 10);
    this._currentVote = this.$voteList.attr("data-user-vote") || "none";

    const buttons = this.$voteList.find(".forum-vote");
    if (!buttons.length) return;
    buttons.on("click", (event) => {
      event.preventDefault();
      const action = parseInt($(event.currentTarget).data("action"), 10);

      if (this.currentVote === scoreToStr(action))
        this.deleteVote()
          .then(() => this.recalculateCounts());
      else if (this.currentVote === "none")
        this.createVote(action)
          .then(() => this.recalculateCounts());
      else
        this.deleteVote()
          .then(() => this.createVote(action))
          .then(() => this.recalculateCounts());
    });
  }


  // ============================== //
  // ======== Getter Magic ======== //
  // ============================== //

  _currentVote: string = undefined;

  get currentVote (): string {
    return this._currentVote;
  }

  set currentVote (vote: string) {
    this._currentVote = vote;
    this.$voteList.attr("data-user-vote", vote);
  }


  // ============================== //
  // ======== Vote Requests ======= //
  // ============================== //

  private createVote (score: number): JQuery.jqXHR {
    return $.ajax({
      url: `/forum_posts/${this.postId}/votes.json`,
      type: "POST",
      dataType: "json",
      data: { "forum_post_vote[score]": score },
    }).done((data: VoteResponse) => {
      this.addVoteToDOM(data);
    }).fail((xhr) => {
      const message: string = xhr?.responseJSON?.reason ?? "Failed to vote on forum post.";
      Flash.error(message);
    });
  }

  private deleteVote (): JQuery.jqXHR {
    return $.ajax({
      url: `/forum_posts/${this.postId}/votes.json`,
      type: "DELETE",
      dataType: "json",
    }).done(() => {
      this.removeVoteFromDOM();
    }).fail((xhr) => {
      const message: string = xhr?.responseJSON?.reason ?? "Failed to remove vote.";
      Flash.error(message);
    });
  }


  // ============================== //
  // ====== DOM Manipulation ====== //
  // ============================== //

  private addVoteToDOM (vote: VoteResponse): void {
    const voteStr = scoreToStr(vote.score);
    const $votesList = this.$voteList.find(`.forum-post-votes[data-vote="${voteStr}"]`);

    const $link = $("<a>")
      .attr({
        "href": `/users/${vote.creator_id}`,
        "rel": "nofollow",
      })
      .addClass("with-style user-" + User.levelString.toLowerCase())
      .text(vote.creator_name.replace(/_+/g, " "));
    const $li = $("<li>").addClass("forum-post-vote own-forum-vote").append($link);
    $votesList.append($li);

    this.currentVote = voteStr;
  }

  private removeVoteFromDOM (): void {
    const $ownVote = this.$voteList.find(".own-forum-vote");
    $ownVote.remove();

    this.currentVote = "none";
  }

  private recalculateCounts (): void {
    let totalVotes = 0;
    for (const category of this.$voteList.find(".forum-post-vote-category")) {
      const $category = $(category);
      const count = $category.find(".forum-post-votes").children("li").length;
      $category.attr("data-vote-count", count);
      totalVotes += count;
    }
    this.$voteList.attr("data-vote-count", totalVotes);
  }
}

$(() => {
  for (const element of $(".forum-post-vote-list"))
    new ForumPostVote(element);
});
