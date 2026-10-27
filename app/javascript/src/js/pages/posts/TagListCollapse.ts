/** Collapsible per-category tag lists in the posts sidebar (index, show and favorites). */
export default class TagListCollapse {

  static initialize (): void {
    $(".tag-list-header").on("click.danbooru", (event) => {
      event.preventDefault();
      const $header = $(event.currentTarget);
      $(`.${$header.data("category")}-tag-list`).toggle();
      $header.toggleClass("hidden-category");
    });
  }
}
