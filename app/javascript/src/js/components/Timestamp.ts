interface FormatSpecification {
  format: string;
  matcher: RegExp;
  get updateIntervalMs(): number;
  get lowerBoundMs(): number;
  upperBoundMs: number;
  nextSmallestFormat?: string;
  nextLargestFormat?: string;
};
type FormatInstanceData = {
  format: string;
  count?: number;
};
type FormatSpecMap = {
  [k: string]: Readonly<FormatSpecification>,

  less_than_x_seconds: Readonly<FormatSpecification>,
  half_a_minute: Readonly<FormatSpecification>,
  less_than_x_minutes: Readonly<FormatSpecification>,
  x_minutes: Readonly<FormatSpecification>,
  about_x_hours: Readonly<FormatSpecification>,
  x_days: Readonly<FormatSpecification>,
  about_x_months: Readonly<FormatSpecification>,
  x_months: Readonly<FormatSpecification>,
  about_x_years: Readonly<FormatSpecification>,
  over_x_years: Readonly<FormatSpecification>,
  almost_x_years: Readonly<FormatSpecification>,
};

/**
 * Automatically updates the displayed time in the same format as the server.
 */
export default class Timestamp {
  public static init () {
    document.querySelectorAll("time").forEach((e) => new Timestamp(e));
  }

  public static readonly MAX_UPDATE_INTERVAL_MS = 24 * 60 * 60 * 1000;
  public static readonly MIN_UPDATE_INTERVAL_MS = 1 * 1000;
  private formatSpec: FormatSpecification;
  private readonly tense: "future" | "past" | "present";
  private count: number;
  private get targetTime () { return new Date(this.element.dateTime); }
  private timerID?: number;
  private readonly options: object = {};
  private pastUpdateInterval = false;

  // #region For title attr. toggling
  private currentText: string;
  private readonly titleBackup: string;
  private readonly isInteractable: boolean;
  // #endregion For title attr. toggling
  constructor (
    public readonly element: HTMLTimeElement,
  ) {
    this.titleBackup = element.title;
    this.isInteractable = element.parentElement.tagName !== "A";
    if (this.isInteractable) {
      this.element.addEventListener("click", this.toggleDisplayedStyle);
    } else {
      const icon = document.createElement("span");
      icon.innerText = "ⓘ";
      icon.style.cursor = "help";
      icon.addEventListener("click", this.toggleDisplayedStyle);
      element.parentElement.parentElement.appendChild(icon);
    }
    const currentText = this.currentText = element.innerText;
    for (const range of Timestamp.ranges) {
      const m = range.matcher.exec(currentText);
      if (!m || !m[0]) continue;
      this.formatSpec = range;
      this.tense = m.groups!["in"] ? "future" : m.groups!["ago"] ? "past" : "present";
      const count = m.groups!["count"] ?? "0";
      this.count = Number.parseInt(count === "a" ? "1" : count);
      // TODO: Options
      this.scheduleNextUpdate();
      return;
    }
    console.warn("Should have matched a pattern (text: %s, element: %o)", currentText, element);
  }

  private toggleDisplayedStyle = () => {
    if (this.currentText === this.element.innerText) {
      this.element.innerText = this.titleBackup;
      this.element.title = this.currentText;
    } else {
      this.element.innerText = this.currentText;
      this.element.title = this.titleBackup;
    }
  };

  private scheduleNextUpdate (doUpdateIfDue = true) {
    if (this.pastUpdateInterval) return false;
    const updateTime = Timestamp.findUpdateInterval(this.formatSpec, this.targetTime);
    if (updateTime) {
      if (updateTime <= 0) {
        if (doUpdateIfDue) this.update();
        return false;
      } else {
        this.timerID = setTimeout(() => this.update(), updateTime);
        return true;
      }
    } else {
      this.pastUpdateInterval = true;
      if (this.timerID) clearTimeout(this.timerID);
      this.timerID = undefined;
      return false;
    }
  }

  private static findUpdateInterval (range: FormatSpecification, from: Date, to = new Date()) {
    let interval = range.updateIntervalMs;
    if (interval > this.MAX_UPDATE_INTERVAL_MS) return undefined;
    interval = Math.max(this.MIN_UPDATE_INTERVAL_MS, interval);
    return interval - Math.round(Timestamp.findDeltas(from, to).deltaMs);
  }

  private update () {
    const newValue = Timestamp.findDeltaFormat(this.targetTime, new Date(), this.options);
    if (newValue.format === this.formatSpec.format && (newValue.count ?? 0) === this.count) {
      this.scheduleNextUpdate(false);
      return;
    }

    this.count = newValue.count;
    this.formatSpec = Timestamp.formats[newValue.format];
    let str = Timestamp.formatToString(newValue);
    switch (this.tense) {
      case "past":
        str = `${str} ago`;
        break;
      case "future":
        str = `in ${str}`;
        break;
      case "present":
      default:
        break;
    }

    if (this.currentText === this.element.innerText) this.element.innerText = str;
    else this.element.title = str;
    this.currentText = str;
    this.scheduleNextUpdate(false);
  }

  public static formats: Readonly<FormatSpecMap> = Object.freeze({
    less_than_x_seconds: Object.freeze({
      format: "less_than_x_seconds",
      matcher: /^(?<in>in )?less than (?<count>a|x|[0-9]+) second(?<plural>s)?(?<ago> ago)?\s*$/,
      get updateIntervalMs () { return 1000; },
      lowerBoundMs: -Infinity,
      upperBoundMs: (19 * 1000) + 500,
      nextSmallestFormat: null,
      nextLargestFormat: "half_a_minute",
    }),
    half_a_minute: Object.freeze({
      format: "half_a_minute",
      matcher: /^(?<in>in )?(?:(?<count>a|x|[0-9]+) )?half(?: a)? minute(?<plural>s)?(?<ago> ago)?\s*$/,
      get updateIntervalMs () { return 20 * 1000; },
      get lowerBoundMs () { return Timestamp.formats[this.nextSmallestFormat].upperBoundMs; },
      upperBoundMs: (39 * 1000) + 500,
      nextSmallestFormat: "less_than_x_seconds",
      nextLargestFormat: "less_than_x_minutes",
    }),
    less_than_x_minutes: Object.freeze({
      format: "less_than_x_minutes",
      matcher: /^(?<in>in )?less than (?<count>a|x|[0-9]+) minute(?<plural>s)?(?<ago> ago)?\s*$/,
      get updateIntervalMs () { return 20 * 1000; },
      get lowerBoundMs () { return Timestamp.formats[this.nextSmallestFormat].upperBoundMs; },
      upperBoundMs: (59 * 1000) + 500,
      nextSmallestFormat: "half_a_minute",
      nextLargestFormat: "x_minutes",
    }),
    x_minutes: Object.freeze({
      format: "x_minutes",
      matcher: /^(?<in>in )?(?<count>a|x|[0-9]+) minute(?<plural>s)?(?<ago> ago)?\s*$/,
      get updateIntervalMs () { return 60 * 1000; },
      get lowerBoundMs () { return Timestamp.formats[this.nextSmallestFormat].upperBoundMs; },
      upperBoundMs: (45 * 60 * 1000),
      nextSmallestFormat: "less_than_x_minutes",
      nextLargestFormat: "about_x_hours",
    }),
    about_x_hours: Object.freeze({
      format: "about_x_hours",
      matcher: /^(?<in>in )?about (?<count>a|x|[0-9]+) hour(?<plural>s)?(?<ago> ago)?\s*$/,
      get updateIntervalMs () { return 60 * 60 * 1000; },
      get lowerBoundMs () { return Timestamp.formats[this.nextSmallestFormat].upperBoundMs; },
      upperBoundMs: 24 * 60 * 60 * 1000, // 24 hours
      nextSmallestFormat: "x_minutes",
      nextLargestFormat: "x_days",
    }),
    x_days: Object.freeze({
      format: "x_days",
      matcher: /^(?<in>in )?(?<count>a|x|[0-9]+) day(?<plural>s)?(?<ago> ago)?\s*$/,
      get updateIntervalMs () { return this.lowerBoundMs; },
      get lowerBoundMs () { return Timestamp.formats[this.nextSmallestFormat].upperBoundMs; },
      upperBoundMs: 30 * 24 * 60 * 60 * 1000, // 30 days
      nextSmallestFormat: "about_x_hours",
      nextLargestFormat: "about_x_months",
    }),
    about_x_months: Object.freeze({
      format: "about_x_months",
      matcher: /^(?<in>in )?about (?<count>a|x|[0-9]+) month(?<plural>s)?(?<ago> ago)?\s*$/,
      get updateIntervalMs () { return this.lowerBoundMs; },
      get lowerBoundMs () { return Timestamp.formats[this.nextSmallestFormat].upperBoundMs; },
      upperBoundMs: 60 * 24 * 60 * 60 * 1000, // 60 days
      nextSmallestFormat: "x_days",
      nextLargestFormat: "x_months",
    }),
    x_months: Object.freeze({
      format: "x_months",
      matcher: /^(?<in>in )?(?<count>a|x|[0-9]+) month(?<plural>s)?(?<ago> ago)?\s*$/,
      get updateIntervalMs () { return 30 * 24 * 60 * 60 * 1000; },
      get lowerBoundMs () { return Timestamp.formats[this.nextSmallestFormat].upperBoundMs; },
      upperBoundMs: 365 * 24 * 60 * 60 * 1000, // 365 days
      nextSmallestFormat: "about_x_months",
      nextLargestFormat: "about_x_years",
    }),
    about_x_years: Object.freeze({
      format: "about_x_years",
      matcher: /^(?<in>in )?about (?<count>a|x|[0-9]+) year(?<plural>s)?(?<ago> ago)?\s*$/,
      get updateIntervalMs () { return this.lowerBoundMs; },
      get lowerBoundMs () { return Timestamp.formats[this.nextSmallestFormat].upperBoundMs; },
      upperBoundMs: Infinity,
      nextSmallestFormat: "x_months",
      nextLargestFormat: "over_x_years",
    }),
    over_x_years: Object.freeze({
      format: "over_x_years",
      matcher: /^(?<in>in )?over (?<count>a|x|[0-9]+) year(?<plural>s)?(?<ago> ago)?\s*$/,
      get updateIntervalMs () { return this.lowerBoundMs; },
      lowerBoundMs: 365 * 24 * 60 * 60 * 1000, // 365 days
      upperBoundMs: Infinity,
      nextSmallestFormat: "about_x_years",
      nextLargestFormat: "almost_x_years",
    }),
    almost_x_years: Object.freeze({
      format: "almost_x_years",
      matcher: /^(?<in>in )?almost (?<count>a|x|[0-9]+) year(?<plural>s)?(?<ago> ago)?\s*$/,
      get updateIntervalMs () { return this.lowerBoundMs; },
      lowerBoundMs: 365 * 24 * 60 * 60 * 1000, // 365 days
      upperBoundMs: Infinity,
      nextSmallestFormat: "over_x_years",
      nextLargestFormat: null,
    }),
  });

  public static ranges = [
    this.formats["less_than_x_seconds"],
    this.formats["half_a_minute"],
    this.formats["less_than_x_minutes"],
    this.formats["x_minutes"],
    this.formats["about_x_hours"],
    this.formats["x_days"],
    this.formats["about_x_months"],
    this.formats["x_months"],
    this.formats["about_x_years"],
    this.formats["over_x_years"],
    this.formats["almost_x_years"],
  ];

  public static formatToString (format: FormatInstanceData) {
    const temp = format.format
      .replace(/_/g, " ")
      .replace(/(?<=^| )x(?!= )/, format.count.toString());
    if ((format.count ?? 1) > 1) return temp;
    return temp.substring(0, temp.length - 1);
  }

  public static timeDeltaInWords (fromTime: Date, options: object) {
    return this.findDeltaFormat(fromTime, new Date(), options);
  }

  private static findDeltas (fromTime: Date, toTime: Date) {
    if (fromTime.valueOf() > toTime.valueOf()) [fromTime, toTime] = [toTime, fromTime];
    const deltaMs = (toTime.valueOf() - fromTime.valueOf()) / 1000,
      deltaMinutes = Math.round(deltaMs / 60),
      deltaSeconds = Math.round(deltaMs);
    return { deltaMs, deltaMinutes, deltaSeconds };
  }

  private static readonly MINUTES_IN_DAY = 1440;
  private static readonly MINUTES_IN_YEAR = 525600;
  private static readonly MINUTES_IN_QUARTER_YEAR = this.MINUTES_IN_YEAR / 4;
  private static readonly MINUTES_IN_THREE_QUARTERS_YEAR = this.MINUTES_IN_QUARTER_YEAR * 3;

  public static findDeltaFormat (fromTime: Date, toTime: Date, options: object): FormatInstanceData {
    if (fromTime.valueOf() > toTime.valueOf()) [fromTime, toTime] = [toTime, fromTime];
    const deltaMs = (toTime.valueOf() - fromTime.valueOf()) / 1000,
      deltaMinutes = Math.round(deltaMs / 60),
      deltaSeconds = Math.round(deltaMs);
    return this.findSubYearDeltaFormat(deltaMinutes, deltaSeconds, options) ?? this.findYearDeltaFormat(fromTime, toTime, deltaMinutes);
  }

  private static findSecondsDeltaFormat (deltaSeconds: number) {
    switch (/* deltaSeconds */true) {
      case deltaSeconds >= 0 && deltaSeconds <= 4:
        return { format: "less_than_x_seconds", count: 5 };
      case deltaSeconds >= 5 && deltaSeconds <= 9:
        return { format: "less_than_x_seconds", count: 10 };
      case deltaSeconds >= 10 && deltaSeconds <= 19:
        return { format: "less_than_x_seconds", count: 20 };
      case deltaSeconds >= 20 && deltaSeconds <= 39:
        return { format: "half_a_minute" };
      case deltaSeconds >= 40 && deltaSeconds <= 59:
        return { format: "less_than_x_minutes", count: 1 };
      default:
        return { format: "x_minutes", count: 1 };
    }
  }

  private static findSubYearDeltaFormat (deltaMinutes: number, deltaSeconds: number, options: object) {
    switch (/* deltaMinutes */true) {
      case deltaMinutes >= 0 && deltaMinutes <= 1:
        if (!options["include_seconds"])
          return deltaMinutes == 0
            ? { format: "less_than_x_minutes", count: 1 }
            : { format: "x_minutes", count: deltaMinutes };

        return this.findSecondsDeltaFormat(deltaSeconds);

      case deltaMinutes >= 2 && deltaMinutes < 45:
        return { format: "x_minutes", count: deltaMinutes };
      case deltaMinutes >= 45 && deltaMinutes < 90:
        return { format: "about_x_hours", count: 1 };
        // 90 mins up to 24 hours
      case deltaMinutes >= 90 && deltaMinutes < this.MINUTES_IN_DAY:
        return { format: "about_x_hours", count: Math.round(deltaMinutes / 60.0) };
        // 24 hours up to 42 hours
      case deltaMinutes >= this.MINUTES_IN_DAY && deltaMinutes < 2520:
        return { format: "x_days", count: 1 };
        // 42 hours up to 30 days
      case deltaMinutes >= 2520 && deltaMinutes < 43200:
        return { format: "x_days", count: Math.round(deltaMinutes / this.MINUTES_IN_DAY) };
        // 30 days up to 60 days
      case deltaMinutes >= 43200 && deltaMinutes < 86400:
        return { format: "about_x_months", count: Math.round(deltaMinutes / 43200.0) };
        // 60 days up to 365 days
      case deltaMinutes >= 86400 && deltaMinutes < 525600:
        return { format: "x_months", count: Math.round(deltaMinutes / 43200.0) };
      default:
        return null;
    }
  }

  private static findYearDeltaFormat (fromTime: Date, toTime: Date, deltaMinutes = Math.round((toTime.valueOf() - fromTime.valueOf()) / (1000 * 60))): FormatInstanceData | undefined | null {
    let from_year = fromTime.getFullYear();
    if (fromTime.getMonth() >= 3)
      from_year += 1;
    let to_year = toTime.getFullYear();
    if (toTime.getMonth() < 3)
      to_year -= 1;

    let leap_years: number;
    if (from_year > to_year)
      leap_years = 0;
    else {
      const fyear = from_year - 1;
      leap_years = ((to_year / 4) - (to_year / 100) + (to_year / 400)) - ((fyear / 4) - (fyear / 100) + (fyear / 400));
    }
    const minute_offset_for_leap_year = leap_years * this.MINUTES_IN_DAY;

    // Discount the leap year days when calculating year distance.
    // e.g. if there are 20 leap year days between 2 dates having the same day
    // and month then based on 365 days calculation
    // the distance in years will come out to over 80 years when in written
    // English it would read better as about 80 years.
    const minutes_with_offset = deltaMinutes - minute_offset_for_leap_year;
    const remainder = (minutes_with_offset % this.MINUTES_IN_YEAR);
    const distance_in_years = (minutes_with_offset / this.MINUTES_IN_YEAR);
    if (remainder < this.MINUTES_IN_QUARTER_YEAR)
      return { format: "about_x_years", count: distance_in_years };
    else if (remainder < this.MINUTES_IN_THREE_QUARTERS_YEAR)
      return { format: "over_x_years", count: distance_in_years };
    else
      return { format: "almost_x_years", count: distance_in_years + 1 };
  }
}

$(() => Timestamp.init());
