import Hotkeys from "@/core/hotkeys";
import CurrentUser from "@/models/CurrentUser";
import { allUrlsValid, isUrlValid, splitUrls } from "./SourceValidation";

/**
 * The post edit form on posts#show: toggled by the sidebar link, the toolbar
 * button and the form's Cancel button. Opening and closing is announced on
 * `document` as `danbooru:open-post-edit-tab` / `danbooru:close-post-edit-tab`,
 * which the lazily mounted tag editor also listens to.
 */
export default class EditTab {

  private static isEditing = false;

  static get editing (): boolean { return EditTab.isEditing; }

  static initialize (): void {
    // The form is only rendered for members
    if (CurrentUser.is.anonymous || !$("#edit").length) return;

    $("#side-edit-link, #post-edit-link, #post-edit-close").on("click.danbooru", (event) => {
      event.preventDefault(); // Only one of these is a link
      EditTab.toggle();
    });

    $(document).on("danbooru:open-post-edit-tab.edittab", () => {
      Hotkeys.enabled = false;
      // Not going to happen until the Vue app is mounted.
      // See tag_editor.vue for the workaround.
      $("#post_tag_string").trigger("focus");
      window.scrollTo({ top: $("#edit").offset().top - 80, behavior: "smooth" });
    });
    $(document).on("danbooru:close-post-edit-tab.edittab", () => { Hotkeys.enabled = true; });

    EditTab.initializeSourceValidation();
  }

  static toggle (): void {
    if (EditTab.isEditing) EditTab.close();
    else EditTab.open();
  }

  static open (): void {
    EditTab.isEditing = true;
    $("#edit").show();
    $(document).trigger("danbooru:open-post-edit-tab");
  }

  static close (): void {
    EditTab.isEditing = false;
    $(document).trigger("danbooru:close-post-edit-tab");
    $("#edit").hide();
  }

  private static initializeSourceValidation (): void {
    const oldSources = splitUrls(String($("input[name='post[old_source]']").val() ?? ""));
    const invalidOldSources = oldSources.filter((url) => !isUrlValid(url));

    const update = () => {
      const newSources = splitUrls(String($("#post_source").val() ?? ""));
      const newSourcesValid = allUrlsValid(newSources, oldSources);
      const error = $("#post-edit-invalid-url-error")[0];
      if (error) error.style.display = newSourcesValid ? "none" : "";
      const submit = $("#edit #form input[type=\"submit\"]")[0] as HTMLInputElement | undefined;
      if (submit) submit.disabled = !newSourcesValid;

      const hasOldInvalidSource = newSources.some((url) => invalidOldSources.includes(url));
      const warning = $("#post-edit-invalid-url-warning")[0];
      if (warning) warning.style.display = hasOldInvalidSource ? "" : "none";
    };

    $(document).on("danbooru:open-post-edit-tab.edittab", update);
    $("#post_source").on("change.danbooru", update);
  }
}
