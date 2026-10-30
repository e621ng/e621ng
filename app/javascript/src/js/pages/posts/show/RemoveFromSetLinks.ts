import PostSet from "@/models/PostSet";

/** The "remove from set" buttons in the posts#show set navigation blocks */
export default class RemoveFromSetLinks {

  /* ============================== */
  /* ===== Singleton pattern ====== */
  /* ============================== */

  private static _instance: RemoveFromSetLinks | null = null;
  public static get instance (): RemoveFromSetLinks {
    if (!RemoveFromSetLinks._instance)
      RemoveFromSetLinks._instance = new RemoveFromSetLinks();
    return RemoveFromSetLinks._instance;
  }


  /* ============================== */
  /* ======= Initialization ======= */
  /* ============================== */

  private constructor () {
    if (RemoveFromSetLinks._instance)
      throw new Error("RemoveFromSetLinks is a singleton class. Use RemoveFromSetLinks.instance to access the instance.");

    for (const link of document.querySelectorAll<HTMLElement>("a.set-nav-remove-link"))
      link.addEventListener("click", (event) => {
        event.preventDefault();
        const { setId, postId } = link.dataset;
        PostSet.remove_post(Number(setId), Number(postId));
      });
  }

}
