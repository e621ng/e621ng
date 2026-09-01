import PerformanceTracker from "@/utility/PerformanceTracker";

/**
 * App-wide performance tracker singleton.
 * Marks "start" when first instantiated during bootstrap.
 */
class AppPerformance extends PerformanceTracker {

  private static _instance: AppPerformance = null;
  public static get instance (): AppPerformance {
    if (!this._instance) this._instance = new AppPerformance();
    return this._instance;
  }

  private constructor () {
    if (AppPerformance._instance)
      throw new Error("AppPerformance is a singleton class. Use AppPerformance.instance to access the instance.");

    super("app");
  }
}

export default AppPerformance.instance;
