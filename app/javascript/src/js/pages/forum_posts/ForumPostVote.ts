export default class ForumPostVote {

  private $voteList: JQuery<HTMLElement>;
  private postId: number;

  constructor(element: HTMLElement) {
    this.$voteList = $(element);
    this.postId = parseInt(this.$voteList.data("forum-id"), 10);

    const buttons = this.$voteList.find(".forum-vote");
    if (!buttons.length) return;
    buttons.on("click", (event) => {
      
    });
  }

}

$(() => {
  for (const element of $(".forum-post-vote-list"))
    new ForumPostVote(element);
});
