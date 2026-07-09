import { CachedPost } from "@/models/PostCache";
import Utility from "@/utility/utility";
import FilterUtilities from "./FilterUtilities";

/**
 * Represents a single word in the filter.
 * Could be a tag, a metatag, a comparison, etc.
 */
export default class FilterToken {

  public readonly optional: boolean;
  public readonly inverted: boolean;
  public readonly type: string;
  public readonly comparison: string;
  public readonly value: any;

  /**
   * Constructor.
   * Provided data should not contain spaces.
   * @param {string} raw Single filter word
   */
  constructor (raw: string) {
    raw = raw.trim().toLowerCase();

    // Token prefixes: ~ for optional, - for inverted
    const prefixMatch = raw.match(/^(~|-)+/);
    if (prefixMatch) {
      const prefix = prefixMatch[0];
      this.optional = prefix.includes("~");
      this.inverted = prefix.includes("-");
      raw = raw.slice(prefix.length);
    } else {
      this.optional = false;
      this.inverted = false;
    }

    // Get filter type: tag, id, score, rating, etc.
    this.type = FilterUtilities.getFilterType(raw);
    if (this.type !== "tag") raw = raw.slice(this.type.length + 1);
    else if (raw.includes("*")) {
      this.value = new RegExp(`^${Utility.regexp_escape(raw).replace(/\\\*/g, ".*")}$`);
      this.type = "wildcard";
      return;
    }

    // Get comparison methods: equals, smaller then, etc
    this.comparison = FilterUtilities.getComparison(raw);
    if (this.comparison != "=" && this.comparison != "..")
      raw = raw.slice(this.comparison.length);

    // Normalize the value and deal with the range syntax
    if (this.comparison == "..") {
      if (raw.startsWith("..")) {
        this.comparison = "<=";
        this.value = FilterUtilities.normalizeData(raw.slice(2), this.type);
      } else if (raw.endsWith("..")) {
        this.comparison = ">=";
        this.value = FilterUtilities.normalizeData(raw.slice(0, -2), this.type);
      } else {
        const parts = raw.split("..");
        if (parts.length != 2) {
          this.comparison = "=";
          this.value = NaN;
        } else {
          this.value = [
            FilterUtilities.normalizeData(parts[0], this.type),
            FilterUtilities.normalizeData(parts[1], this.type),
          ];
        }
      }
    } else {
      this.value = FilterUtilities.normalizeData(raw, this.type);
      if (this.comparison === "=" && this.type === "filesize") {
        // If the comparison uses direct equality, mirror the fudging behavior of
        // the filesize search metatag by changing the comparison to a range of
        // the initial value -5% and +5%.
        this.comparison = "..";
        this.value = [
          Math.trunc(this.value * 0.95),
          Math.trunc(this.value * 1.05),
        ];
      }
    }
  }

  /**
   * Checks if the filter token is applicable to the specified post
   * @param {CachedPost} post Post to test
   * @returns true if the filter token matches
   */
  public test (post: CachedPost): boolean {
    const val = FilterUtilities.FilterTests[this.type](this, post);
    return this.inverted ? !val : val;
  }
}
