import State from "@/utility/StateUtils";

type ClickListener = (event: MouseEvent) => void;
export type ParseResult = { page: number } | { error: string } | null;

// Module re-imports (specs) must replace the listener, not stack a second one
const LISTENER_KEY = Symbol.for("e621.paginatorfasttravel.listener");

/**
 * "Jump to page" prompt behind the paginator's ellipsis buttons.
 * Input is validated client-side so typos never reach the server's error page.
 */
export default class PaginatorFastTravel {

  /**
   * @param input Raw prompt value
   * @param total Highest reachable page
   * @returns The page, an error message, or null if the prompt was cancelled or left empty
   */
  public static parse (input: string | null, total: number): ParseResult {
    const value = input?.trim();
    if (!value) return null;

    const page = /^\d+$/.test(value) ? Number(value) : NaN;
    if (!(page >= 1 && page <= total))
      return { error: `Enter a page number between 1 and ${total}.` };
    return { page };
  }

  /** Current URL with only the page swapped out */
  public static urlFor (page: number): string {
    const url = new URL(window.location.href);
    url.searchParams.set("page", String(page));
    return url.toString();
  }

  /** Prompts until a valid page is entered or the prompt is cancelled */
  public static ask (total: number): number | null {
    let message = "Navigate to page";
    let input = "";
    for (;;) {
      input = window.prompt(message, input);
      const result = PaginatorFastTravel.parse(input, total);
      if (!result) return null;
      if ("page" in result) return result.page;

      message = result.error;
    }
  }

  public static bootstrap (): void {
    const listener: ClickListener = (event) => {
      const button = (event.target as Element | null)?.closest<HTMLButtonElement>("nav.pagination button.spacer");
      if (!button) return;

      event.preventDefault();
      const total = Number(button.closest<HTMLElement>("nav.pagination").dataset.total);
      const page = PaginatorFastTravel.ask(total);
      if (page !== null) window.location.assign(PaginatorFastTravel.urlFor(page));
    };

    const host = window as unknown as Record<symbol, ClickListener | undefined>;
    const previous = host[LISTENER_KEY];
    if (previous) document.removeEventListener("click", previous);
    host[LISTENER_KEY] = listener;
    document.addEventListener("click", listener);
  }
}

State.onReady(() => PaginatorFastTravel.bootstrap());
