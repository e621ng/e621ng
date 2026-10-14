import Logger from "@/utility/Logger";
import Performance from "@/utility/Performance";

class ModuleRegistry {

  /* ============================== */
  /* ===== Singleton Pattern ====== */
  /* ============================== */

  private static _instance: ModuleRegistry = null;
  public static get instance (): ModuleRegistry {
    if (!this._instance) this._instance = new ModuleRegistry();
    return this._instance;
  }

  private constructor () {
    if (ModuleRegistry._instance)
      throw new Error("ModuleRegistry is a singleton class. Use ModuleRegistry.instance to access the instance.");
  }


  /* ============================== */
  /* ========== Registry ========== */
  /* ============================== */

  private modules: string[] = [];
  private exports = 0;

  public register (name: string, exported: ExportedModule = {}): void {
    this.modules.push(name);

    let exportCount = 0;
    for (const [key, object] of Object.entries(exported)) {
      window["E621"][key] = object; // Expose the export on the global for external tools
      exportCount++;
    }
    this.exports += exportCount;

    Logger.loaded(name, exportCount);
    Performance.mark(`module-${name}`);
  }

  public get list (): string[] {
    return this.modules;
  }

  public get exportCount (): number {
    return this.exports;
  }

}

interface ExportedModule {
  [name: string]: any;
}

export default ModuleRegistry.instance;
