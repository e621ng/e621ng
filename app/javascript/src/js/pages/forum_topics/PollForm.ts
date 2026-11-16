/**
 * Row management for the poll fields, used by the new-topic form and the inline
 * poll edit form. Without JS the poll fieldset stays disabled, so no poll is submitted.
 */
export default class PollForm {

  /* ============================== */
  /* ===== Singleton pattern ====== */
  /* ============================== */

  private static _instance: PollForm | null = null;
  public static get instance (): PollForm {
    if (!PollForm._instance)
      PollForm._instance = new PollForm();
    return PollForm._instance;
  }


  /* ============================== */
  /* ======= Initialization ======= */
  /* ============================== */

  private constructor () {
    if (PollForm._instance)
      throw new Error("PollForm is a singleton class. Use PollForm.instance to access the instance.");

    const toggle = document.querySelector<HTMLInputElement>("#forum-topic-add-poll");
    const fieldset = document.querySelector<HTMLFieldSetElement>("fieldset.forum-poll-fieldset");
    if (toggle && fieldset) {
      const apply = () => {
        fieldset.disabled = !toggle.checked;
        fieldset.hidden = !toggle.checked;
      };
      toggle.addEventListener("change", apply);
      apply();
    }

    for (const container of document.querySelectorAll<HTMLElement>(".forum-poll-fields"))
      this.bindFields(container);

    const editLink = document.querySelector<HTMLAnchorElement>(".forum-poll-edit-link");
    const editPanel = document.querySelector<HTMLElement>("#forum-poll-edit");
    if (editLink && editPanel)
      editLink.addEventListener("click", (event) => {
        event.preventDefault();
        editPanel.hidden = !editPanel.hidden;
      });
  }

  private bindFields (container: HTMLElement): void {
    const rows = container.querySelector<HTMLElement>(".forum-poll-option-rows");
    const template = container.querySelector<HTMLTemplateElement>("template.forum-poll-option-template");
    const addButton = container.querySelector<HTMLButtonElement>(".forum-poll-add-option");
    const maxOptions = parseInt(container.dataset.maxOptions ?? "20", 10);
    if (!rows || !template || !addButton) return;

    const liveRows = () => Array.from(rows.querySelectorAll<HTMLElement>(".forum-poll-option-row"))
      .filter((row) => row.dataset.destroyed !== "true");

    const refresh = () => {
      addButton.disabled = liveRows().length >= maxOptions;
    };

    addButton.addEventListener("click", () => {
      if (liveRows().length >= maxOptions) return;
      const html = template.innerHTML.replace(/__INDEX__/g, String(Date.now()));
      rows.insertAdjacentHTML("beforeend", html);
      refresh();
      const inputs = rows.querySelectorAll<HTMLInputElement>("input[type='text']");
      inputs[inputs.length - 1]?.focus();
    });

    rows.addEventListener("click", (event) => {
      const button = (event.target as HTMLElement).closest<HTMLButtonElement>(".forum-poll-remove-option");
      if (!button) return;
      const row = button.closest<HTMLElement>(".forum-poll-option-row");
      if (!row) return;

      // Persisted options are flagged for destruction so the server can delete them;
      // unsaved rows are simply dropped from the form.
      const idInput = row.querySelector<HTMLInputElement>("input[name$='[id]']");
      const destroyInput = row.querySelector<HTMLInputElement>(".forum-poll-option-destroy");
      if (idInput && destroyInput) {
        destroyInput.value = "1";
        row.dataset.destroyed = "true";
        row.hidden = true;
      } else {
        row.remove();
      }
      refresh();
    });

    const multiple = container.querySelector<HTMLInputElement>(".forum-poll-allow-multiple");
    const maxChoices = container.querySelector<HTMLInputElement>(".forum-poll-max-choices");
    if (multiple && maxChoices) {
      const applyMultiple = () => {
        maxChoices.disabled = !multiple.checked;
        if (!multiple.checked) maxChoices.value = "1";
        else if (parseInt(maxChoices.value, 10) <= 1) maxChoices.value = "2";
      };
      multiple.addEventListener("change", applyMultiple);
      applyMultiple();
    }

    refresh();
  }
}
