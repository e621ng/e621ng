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
    this.voteCount = parseInt(this.$voteList.data("vote-count"), 10) || 0;

    const buttons = this.$voteList.find(".forum-vote");
    if (!buttons.length) return;
    buttons.on("click", (event) => {
      event.preventDefault();
      const $category = $(event.currentTarget).closest(".forum-post-vote-category");
      const clickedScore = parseInt($category.data("score"), 10);
      const clickedVoteStr = $category.data("vote") as string;
      const currentVote = this.$voteList.attr("data-user-vote") as string;

      if (currentVote === clickedVoteStr) {
        this.deleteVote().then(() => {
          this.voteCount--;
          this.recalculateCounts();
        });
      } else if (currentVote === "none") {
        this.createVote(clickedScore).then(() => {
          this.voteCount++;
          this.recalculateCounts();
        });
      } else {
        this.deleteVote()
          .then(() => this.createVote(clickedScore))
          .then(() => {
            this.recalculateCounts();
          });
      }
    });
  }


  // ============================== //
  // ======== Getter Magic ======== //
  // ============================== //

  get userVote (): string {
    return this.$voteList.attr("data-user-vote") as string;
  }

  set userVote (vote: string) {
    this.$voteList.attr("data-user-vote", vote);
  }

  get voteCount (): number {
    return parseInt(this.$voteList.attr("data-vote-count") as string, 10) || 0;
  }

  set voteCount (count: number) {
    this.$voteList.attr("data-vote-count", count.toString());
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
      const message: string = xhr?.responseJSON?.message ?? "Failed to vote on forum post.";
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
      const message: string = xhr?.responseJSON?.message ?? "Failed to remove vote.";
      Flash.error(message);
    });
  }


  // ============================== //
  // ====== DOM Manipulation ====== //
  // ============================== //

  private addVoteToDOM (vote: VoteResponse): void {
    const voteStr = scoreToStr(vote.score);
    const $votesList = this.$voteList.find(`.forum-post-votes[data-vote="${voteStr}"]`);

    const $link = $("<a>").attr("href", `/users/${vote.creator_id}`).attr("rel", "nofollow").text(vote.creator_name);
    const $li = $("<li>").addClass("forum-post-vote own-forum-vote").append($link);
    $votesList.prepend($li);

    this.userVote = voteStr;
  }

  private removeVoteFromDOM (): void {
    const $ownVote = this.$voteList.find(".own-forum-vote");
    $ownVote.remove();

    this.userVote = "none";
  }

  private recalculateCounts (): void {
    for (const category of this.$voteList.find(".forum-post-vote-category")) {
      const $category = $(category);
      const count = $category.find(".forum-post-votes").children("li").length;
      $category.attr("data-count", count.toString());
    }
  }
}

$(() => {
  for (const element of $(".forum-post-vote-list"))
    new ForumPostVote(element);
});
