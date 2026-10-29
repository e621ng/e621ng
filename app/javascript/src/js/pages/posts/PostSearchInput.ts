/** The tag search textarea (posts index / show, favorites): grows with its content, Enter submits. */
export default class PostSearchInput {

  static initialize (): void {
    for (const section of document.querySelectorAll(".post-search")) {
      const textarea = section.querySelector<HTMLTextAreaElement>("textarea[name='tags']");
      if (textarea) PostSearchInput.bind(textarea);
    }
  }

  private static bind (textarea: HTMLTextAreaElement): void {
    const resize = () => {
      textarea.style.height = "0";
      textarea.style.height = textarea.scrollHeight + "px";
    };

    textarea.addEventListener("input", resize);
    window.addEventListener("resize", resize);
    resize();

    // Bound on the form so autocomplete's keydown (which claims Enter on a selected suggestion) always runs first
    const form = textarea.form;
    form?.addEventListener("keydown", (event) => {
      if (event.target !== textarea || event.key !== "Enter") return;
      if (event.shiftKey || event.isComposing || event.defaultPrevented) return;

      event.preventDefault();
      form.requestSubmit(); // fires submit handlers, unlike form.submit()
    });
  }
}
