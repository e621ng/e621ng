import E621Type from "@/interfaces/E621";
import Logger from "@/utility/Logger";

declare const E621: E621Type;

$(() => {
  performance.mark("app-end");

  const data = [
    "Loaded",
    `\n ⤷ in ${performance.measure("appm", "app-start", "app-end").duration.toFixed(2)} ms`,
  ];
  const measures = ["appm"];
  if (E621.Registry.list.length) {
    data.push(`\n ⤷ with ${E621.Registry.list.length} module${E621.Registry.list.length > 1 ? "s" : ""}`);
    for (const module of E621.Registry.list) {
      data.push(`\n   - ${module}: ${performance.measure(`appm-module-${module}`, `app-start`, `app-module-${module}`).duration.toFixed(2)} ms`);
      measures.push(`appm-module-${module}`);
    }
  }
  if (E621.Registry.exportCount) data.push(`\n ⤷ with ${E621.Registry.exportCount} export${E621.Registry.exportCount > 1 ? "s" : ""}`);

  Logger.log(...data);
  for (const measure of measures)
    window.performance.clearMeasures(measure);
});
