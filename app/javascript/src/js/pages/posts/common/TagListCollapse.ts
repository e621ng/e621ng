/** Collapsible per-category tag lists in the posts sidebar (index, show and favorites). */
export default class TagListCollapse {

  /* ============================== */
  /* ===== Singleton pattern ====== */
  /* ============================== */

  private static _instance: TagListCollapse | null = null;
  public static get instance (): TagListCollapse {
    if (!TagListCollapse._instance)
      TagListCollapse._instance = new TagListCollapse();
    return TagListCollapse._instance;
  }


  /* ============================== */
  /* ======= Initialization ======= */
  /* ============================== */

  private constructor () {
    if (TagListCollapse._instance)
      throw new Error("TagListCollapse is a singleton class. Use TagListCollapse.instance to access the instance.");

    $(".tag-list-header").on("click.danbooru", (event) => {
      event.preventDefault();
      const $header = $(event.currentTarget);
      $(`.${$header.data("category")}-tag-list`).toggle();
      $header.toggleClass("hidden-category");
    });
  }
}
