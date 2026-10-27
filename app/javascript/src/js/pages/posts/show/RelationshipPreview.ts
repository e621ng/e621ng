import CurrentPost from "@/models/CurrentPost";
import LStorage from "@/utility/storage/Local";

/** The collapsible parent / child thumbnails on posts#show. Both open and close together. */
export default class RelationshipPreview {

  static initialize (): void {
    if (CurrentPost.exists) $(`[id=post_${CurrentPost.id}]`).addClass("current-post");

    RelationshipPreview.apply(LStorage.Posts.ShowPostChildren);

    $("#has-children-relationship-preview-link, #has-parent-relationship-preview-link").on("click.danbooru", (event) => {
      event.preventDefault();
      RelationshipPreview.toggle();
    });
  }

  static apply (shown: boolean): void {
    $("#has-children-relationship-preview, #has-parent-relationship-preview").toggle(shown);
    $("#has-children-relationship-preview-link, #has-parent-relationship-preview-link").text(shown ? "« hide" : "show »");
  }

  static toggle (): void {
    LStorage.Posts.ShowPostChildren = !LStorage.Posts.ShowPostChildren;
    RelationshipPreview.apply(LStorage.Posts.ShowPostChildren);
  }
}
