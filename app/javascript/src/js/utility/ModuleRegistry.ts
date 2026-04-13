import E621Type from "@/interfaces/E621";
declare const E621: E621Type;

export default class ModuleRegistry {

  private modules: string[];
  private exports = 0;

  constructor () {
    this.modules = [];
  }

  public register (name: string, exported: ExportedModule = {}): void {
    this.modules.push(name);

    let exportCount = 0;
    for (const [name, object] of Object.entries(exported)) {
      E621[name] = object;
      exportCount++;
    }
    this.exports += exportCount;

    E621.Logger.loaded(name, exportCount);
    E621.Performance.mark(`module-${name}`);
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
