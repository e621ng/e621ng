import E621Type from "@/interfaces/E621";
import Logger from "@/utility/Logger";

declare const E621: E621Type;

$(() => {
  const perf = E621.Performance;
  perf.mark("end");

  const data = [
    "Loaded",
    `\n ⤷ in ${perf.measurePretty("start", "end")}`,
  ];
  if (E621.Registry.list.length) {
    data.push(`\n ⤷ with ${E621.Registry.list.length} module${E621.Registry.list.length > 1 ? "s" : ""}`);
    for (const module of E621.Registry.list) {
      data.push(`\n   - ${module}: ${perf.measurePretty(`start`, `module-${module}`)}`);
    }
  }
  if (E621.Registry.exportCount) data.push(`\n ⤷ with ${E621.Registry.exportCount} export${E621.Registry.exportCount > 1 ? "s" : ""}`);

  Logger.log(...data);
  perf.clear();
});
