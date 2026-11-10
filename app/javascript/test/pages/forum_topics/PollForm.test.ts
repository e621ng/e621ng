import { afterEach, describe, expect, it } from "vitest";

function rowHTML (index: string, persisted = false): string {
  return `<div class="forum-poll-option-row">
    <div class="input"><input type="text" name="forum_topic[poll_attributes][options_attributes][${index}][body]"></div>
    <input type="hidden" class="forum-poll-option-destroy" name="forum_topic[poll_attributes][options_attributes][${index}][_destroy]" value="0">
    <button type="button" class="forum-poll-remove-option">x</button>
    ${persisted ? `<input type="hidden" name="forum_topic[poll_attributes][options_attributes][${index}][id]" value="${index}">` : ""}
  </div>`;
}

function render (opts: { maxOptions?: number; persisted?: boolean; multiple?: boolean; disabled?: boolean } = {}): void {
  const toggle = `<input type="checkbox" id="forum-topic-add-poll" ${opts.disabled ? "" : "checked"}>`;
  document.body.innerHTML = `
    ${toggle}
    <fieldset class="forum-poll-fieldset" ${opts.disabled ? "disabled hidden" : ""}>
      <div class="forum-poll-fields" data-max-options="${opts.maxOptions ?? 20}">
        <div class="forum-poll-option-rows">${rowHTML("0", opts.persisted)}${rowHTML("1", opts.persisted)}</div>
        <template class="forum-poll-option-template">${rowHTML("__INDEX__")}</template>
        <button type="button" class="forum-poll-add-option">Add option</button>
        <input type="checkbox" class="forum-poll-allow-multiple" ${opts.multiple ? "checked" : ""}>
        <input type="number" class="forum-poll-max-choices" value="${opts.multiple ? 2 : 1}">
      </div>
    </fieldset>`;
}

async function load (): Promise<void> {
  const { default: PollForm } = await import("@/pages/forum_topics/PollForm");
  void PollForm.instance;
}

const $ = <T extends Element>(selector: string): T => document.querySelector(selector) as T;
const rows = () => document.querySelectorAll(".forum-poll-option-row");

describe("PollForm", () => {
  afterEach(() => { document.body.innerHTML = ""; });

  it("enables the fieldset only while 'Add a poll' is checked", async () => {
    render({ disabled: true });
    await load();
    const fieldset = $<HTMLFieldSetElement>("fieldset");
    const toggle = $<HTMLInputElement>("#forum-topic-add-poll");
    expect(fieldset.disabled).toBe(true);
    expect(fieldset.hidden).toBe(true);

    toggle.checked = true;
    toggle.dispatchEvent(new Event("change"));
    expect(fieldset.disabled).toBe(false);
    expect(fieldset.hidden).toBe(false);
  });

  it("adds rows from the template with a fresh index", async () => {
    render();
    await load();
    $<HTMLButtonElement>(".forum-poll-add-option").click();
    expect(rows()).toHaveLength(3);
    const name = (rows()[2].querySelector("input[type='text']") as HTMLInputElement).name;
    expect(name).not.toContain("__INDEX__");
    expect(name).toMatch(/options_attributes\]\[\d+\]\[body\]/);
  });

  it("caps the row count at data-max-options", async () => {
    render({ maxOptions: 3 });
    await load();
    const add = $<HTMLButtonElement>(".forum-poll-add-option");
    add.click();
    expect(rows()).toHaveLength(3);
    expect(add.disabled).toBe(true);
    add.click();
    expect(rows()).toHaveLength(3);
  });

  it("drops unsaved rows and flags persisted rows for destruction", async () => {
    render({ persisted: true });
    await load();
    $<HTMLButtonElement>(".forum-poll-add-option").click();
    expect(rows()).toHaveLength(3);

    (rows()[2].querySelector(".forum-poll-remove-option") as HTMLButtonElement).click();
    expect(rows()).toHaveLength(2);

    (rows()[0].querySelector(".forum-poll-remove-option") as HTMLButtonElement).click();
    expect(rows()).toHaveLength(2);
    const first = rows()[0] as HTMLElement;
    expect(first.hidden).toBe(true);
    expect((first.querySelector(".forum-poll-option-destroy") as HTMLInputElement).value).toBe("1");
  });

  it("ties max_choices to the multiple-selection toggle", async () => {
    render();
    await load();
    const multiple = $<HTMLInputElement>(".forum-poll-allow-multiple");
    const max = $<HTMLInputElement>(".forum-poll-max-choices");
    expect(max.disabled).toBe(true);
    expect(max.value).toBe("1");

    multiple.checked = true;
    multiple.dispatchEvent(new Event("change"));
    expect(max.disabled).toBe(false);
    expect(max.value).toBe("2");

    multiple.checked = false;
    multiple.dispatchEvent(new Event("change"));
    expect(max.disabled).toBe(true);
    expect(max.value).toBe("1");
  });

  it("boots without a poll section on the page", async () => {
    document.body.innerHTML = "<div id='c-forum-topics'></div>";
    await expect(load()).resolves.toBeUndefined();
  });
});
