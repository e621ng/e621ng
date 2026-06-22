function addRow (list: HTMLElement, focus = true): void {
  const inputName = list.dataset.inputName;
  const row = document.createElement("div");
  row.className = "redirect-uri-row";

  const input = document.createElement("input");
  input.type = "url";
  input.name = inputName;
  input.placeholder = "https://example.com/oauth/callback";
  row.appendChild(input);

  const remove = document.createElement("button");
  remove.type = "button";
  remove.className = "redirect-uri-remove";
  remove.setAttribute("aria-label", "Remove");
  remove.innerHTML = "&times;";
  row.appendChild(remove);

  list.appendChild(row);
  if (focus) input.focus();
}

function removeRow (list: HTMLElement, row: Element): void {
  row.remove();
  if (list.children.length === 0) addRow(list, false);
}

function wireList (list: HTMLElement): void {
  list.addEventListener("click", (event) => {
    const button = (event.target as Element).closest(".redirect-uri-remove");
    if (!button) return;
    event.preventDefault();
    removeRow(list, button.closest(".redirect-uri-row"));
  });

  const addButton = list.parentElement.querySelector(".redirect-uri-add");
  if (addButton) {
    addButton.addEventListener("click", (event) => {
      event.preventDefault();
      addRow(list);
    });
  }
}

document.addEventListener("DOMContentLoaded", () => {
  document.querySelectorAll<HTMLElement>(".redirect-uri-list").forEach(wireList);
});
