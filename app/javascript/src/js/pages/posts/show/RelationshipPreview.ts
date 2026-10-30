import CurrentPost from "@/models/CurrentPost";
import LStorage from "@/utility/storage/Local";

/** The collapsible parent / child thumbnails on posts#show. Both open and close together. */
export default class RelationshipPreview {

  /* ============================== */
  /* ===== Singleton pattern ====== */
  /* ============================== */

  private static _instance: RelationshipPreview | null = null;
  public static get instance (): RelationshipPreview {
    if (!RelationshipPreview._instance)
      RelationshipPreview._instance = new RelationshipPreview();
    return RelationshipPreview._instance;
  }


  /* ============================== */
  /* ======= Initialization ======= */
  /* ============================== */

  private constructor () {
    if (RelationshipPreview._instance)
      throw new Error("RelationshipPreview is a singleton class. Use RelationshipPreview.instance to access the instance.");

    if (CurrentPost.exists) $(`[id=post_${CurrentPost.id}]`).addClass("current-post");

    this.apply(LStorage.Posts.ShowPostChildren);

    $("#has-children-relationship-preview-link, #has-parent-relationship-preview-link").on("click.danbooru", (event) => {
      event.preventDefault();
      this.toggle();
    });
  }

  public apply (shown: boolean): void {
    $("#has-children-relationship-preview, #has-parent-relationship-preview").toggle(shown);
    $("#has-children-relationship-preview-link, #has-parent-relationship-preview-link").text(shown ? "« hide" : "show »");
  }

  public toggle (): void {
    LStorage.Posts.ShowPostChildren = !LStorage.Posts.ShowPostChildren;
    this.apply(LStorage.Posts.ShowPostChildren);
  }
}
