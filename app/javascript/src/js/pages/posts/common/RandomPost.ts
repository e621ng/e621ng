import Hotkeys from "@/core/hotkeys";

/** The `random` hotkey: a random post, narrowed to the current search when there is one. */
export default class RandomPost {

  /* ============================== */
  /* ===== Singleton pattern ====== */
  /* ============================== */

  private static _instance: RandomPost | null = null;
  public static get instance (): RandomPost {
    if (!RandomPost._instance)
      RandomPost._instance = new RandomPost();
    return RandomPost._instance;
  }


  /* ============================== */
  /* ======= Initialization ======= */
  /* ============================== */

  private constructor () {
    if (RandomPost._instance)
      throw new Error("RandomPost is a singleton class. Use RandomPost.instance to access the instance.");

    Hotkeys.register("random", () => RandomPost.navigate(RandomPost.href()));
  }

  static href (): string {
    const query = String($("#tags").val() ?? "");
    const tags = query.split(" ").filter((tag) => tag).map((tag) => encodeURIComponent(tag));
    return tags.length ? "/posts/random?tags=" + tags.join("+") : "/posts/random";
  }

  private static navigate (href: string): void {
    location.href = href;
  }
}
