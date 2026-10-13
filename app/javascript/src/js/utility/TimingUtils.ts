export default class TimingUtils {
  public static debounce<P extends any[]>(func: (...args: P) => void, delay: number): (...args: P) => void {
    let timer: number;

    return (...args: P) => {
      clearTimeout(timer);
      timer = setTimeout(() => {
        func(...args);
      }, delay);
    };
  }

  public static throttle<P extends any[]>(func: (...args: P) => void, limit: number): (...args: P) => void {
    let inThrottle: boolean;

    return (...args: P) => {
      if (inThrottle) return;
      func(...args);
      inThrottle = true;
      setTimeout(() => (inThrottle = false), limit);
    };
  }
}
