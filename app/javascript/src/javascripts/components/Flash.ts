import $ from "jquery";

export default class Flash {

  private static timeout_id: number = undefined;

  public static notice (message: string, permanent: boolean = false) {
    $("#notice")
      .addClass("ui-state-highlight")
      .removeClass("ui-state-error")
      .fadeIn("fast")
      .children("span")
      .html(message);

    if (this.timeout_id !== undefined)
      clearTimeout(this.timeout_id);

    if (!permanent)
      this.timeout_id = setTimeout(() => {
        $("#close-notice-link").click();
        this.timeout_id = undefined;
      }, 3000);
  };

  public static error (message: string) {
    $("#notice")
      .removeClass("ui-state-highlight")
      .addClass("ui-state-error")
      .fadeIn("fast")
      .children("span")
      .html(message);

    if (this.timeout_id !== undefined)
      clearTimeout(this.timeout_id);
  };

}