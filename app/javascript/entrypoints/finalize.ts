import ModuleRegistry from "@/utility/ModuleRegistry";
import Logger from "@/utility/Logger";
import Performance from "@/utility/Performance";

$(() => {
  const perf = Performance;
  perf.mark("end");

  const data = [
    "Loaded",
    `\n ⤷ in ${perf.measurePretty("start", "end")}`,
  ];
  if (ModuleRegistry.list.length) {
    data.push(`\n ⤷ with ${ModuleRegistry.list.length} module${ModuleRegistry.list.length > 1 ? "s" : ""}`);
    for (const module of ModuleRegistry.list) {
      data.push(`\n   - ${module}: ${perf.measurePretty("start", `module-${module}`)}`);
    }
  }
  if (ModuleRegistry.exportCount) data.push(`\n ⤷ with ${ModuleRegistry.exportCount} export${ModuleRegistry.exportCount > 1 ? "s" : ""}`);

  Logger.log(...data);
  perf.clear();
});
