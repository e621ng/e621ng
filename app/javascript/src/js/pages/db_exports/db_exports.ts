class DbExports {
  static init () {
    document.querySelectorAll<HTMLDivElement>(".exports-list .row").forEach((row) => {
      const toggle = row.querySelector<HTMLDetailsElement>(".row-toggle");
      if (!toggle) return;

      row.addEventListener("click", (event) => {
        const target = event.target as HTMLElement;
        if (target.closest("a, input, summary, .time-switchable")) return;
        toggle.open = !toggle.open;
      });
    });
  }
}

$(() => DbExports.init());

export default DbExports;
