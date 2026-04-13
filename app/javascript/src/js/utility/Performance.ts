export default class Performance {

  private name: string;

  private marks: string[] = [];
  private notes: { [label: string]: string } = {};

  constructor (name: string) {
    this.name = name;
    this.mark("start");
  }

  public mark (label: string, note: string | null = null): void {
    this.marks.push(label);
    if (note) this.notes[label] = note;

    performance.mark(`${this.name}-${label}`);
  }

  public hasMark (label: string): boolean {
    return this.marks.includes(label);
  }

  public measure (startLabel: string, endLabel: string): number {
    const measureName = `${this.name}-${startLabel}-to-${endLabel}`;
    try {
      const result = performance.measure(measureName, `${this.name}-${startLabel}`, `${this.name}-${endLabel}`).duration;
      performance.clearMeasures(measureName);
      return result;
    } catch (e) {
      console.error(`Failed to measure performance from ${startLabel} to ${endLabel}:`, e);
      return -1;
    }
  }

  public measurePretty (startLabel: string, endLabel: string): string {
    const duration = this.measure(startLabel, endLabel);
    if (duration < 0) return "N/A";
    let message = `${duration.toFixed(2)} ms`;
    if (this.notes[endLabel])
      message += ` (${this.notes[endLabel]})`;

    return message;
  }

  public clear (): void {
    for (const mark of this.marks)
      performance.clearMarks(`${this.name}-${mark}`);
    this.marks = [];
    this.notes = {};
  }
}
