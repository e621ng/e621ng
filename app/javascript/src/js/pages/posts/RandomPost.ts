import Hotkeys from "@/core/hotkeys";

/** The `random` hotkey: a random post, narrowed to the current search when there is one. */
export default class RandomPost {

  static href (): string {
    const query = String($("#tags").val() ?? "");
    const tags = query.split(" ").filter((tag) => tag).map((tag) => encodeURIComponent(tag));
    return tags.length ? "/posts/random?tags=" + tags.join("+") : "/posts/random";
  }

  static registerHotkey (): void {
    Hotkeys.register("random", () => RandomPost.navigate(RandomPost.href()));
  }

  private static navigate (href: string): void {
    location.href = href;
  }
}
