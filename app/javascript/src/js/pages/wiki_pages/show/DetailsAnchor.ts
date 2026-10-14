// Native expansion of a closed <details> on fragment navigation is inconsistent across
// browsers, so open the target's <details> ancestors ourselves.

function revealAnchoredDetails (): void {
  const raw = window.location.hash.slice(1);
  if (!raw) return;

  let id: string;
  try {
    id = decodeURIComponent(raw);
  } catch {
    id = raw;
  }

  const target = document.getElementById(id);
  if (!target) return;

  let node: HTMLElement | null = target;
  let opened = false;
  while (node) {
    if (node instanceof HTMLDetailsElement && !node.open) {
      node.open = true;
      opened = true;
    }
    node = node.parentElement;
  }

  if (opened) target.scrollIntoView({ block: "start" });
}

$(() => revealAnchoredDetails());
$(window).on("hashchange.e6.details", revealAnchoredDetails);
