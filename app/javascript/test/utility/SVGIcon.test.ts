import { describe, expect, it } from "vitest";
import SVGIcon from "@/utility/SVGIcon";

const SVG_NS = "http://www.w3.org/2000/svg";

// innerHTML re-serializes self-closing tags as explicit pairs, so compare
// against the same markup parsed the same way rather than the raw string.
function parsedMarkup (name: string): string {
  const ref = document.createElementNS(SVG_NS, "svg");
  ref.innerHTML = SVGIcon.ICONS[name];
  return ref.innerHTML;
}

// Mirrors the attribute list emitted by IconHelper#svg_icon.
const EXPECTED_ATTRIBUTES: Record<string, string> = {
  "xmlns": SVG_NS,
  "width": "16",
  "height": "16",
  "viewBox": "0 0 24 24",
  "fill": "none",
  "stroke": "currentColor",
  "stroke-width": "2",
  "stroke-linecap": "round",
  "stroke-linejoin": "round",
  "name": "copy",
};

describe("SVGIcon", () => {
  it("returns null for unknown names", () => {
    expect(SVGIcon.render("nope")).toBeNull();
    expect(SVGIcon.render("")).toBeNull();
  });

  it("returns null for prototype keys", () => {
    expect(SVGIcon.render("constructor")).toBeNull();
    expect(SVGIcon.render("toString")).toBeNull();
    expect(SVGIcon.render("__proto__")).toBeNull();
    expect(SVGIcon.render("hasOwnProperty")).toBeNull();
  });

  it("renders an svg with exactly the server-side attribute list", () => {
    const svg = SVGIcon.render("copy")!;
    expect(svg.tagName.toLowerCase()).toBe("svg");

    const actual: Record<string, string> = {};
    for (const attr of Array.from(svg.attributes)) actual[attr.name] = attr.value;
    expect(actual).toEqual(EXPECTED_ATTRIBUTES);
  });

  it("stamps the icon name on the element", () => {
    expect(SVGIcon.render("favorites")!.getAttribute("name")).toBe("favorites");
    expect(SVGIcon.render("arrow_up")!.getAttribute("name")).toBe("arrow_up");
  });

  it("reproduces the icon markup", () => {
    const svg = SVGIcon.render("times")!;
    expect(svg.innerHTML).toBe(parsedMarkup("times"));
  });

  it("renders every registered icon with at least one child in the svg namespace", () => {
    for (const name of Object.keys(SVGIcon.ICONS)) {
      const svg = SVGIcon.render(name);
      expect(svg, name).not.toBeNull();
      expect(svg!.namespaceURI, name).toBe(SVG_NS);
      expect(svg!.children.length, name).toBeGreaterThan(0);
      for (const child of Array.from(svg!.children))
        expect(child.namespaceURI, `${name} > ${child.tagName}`).toBe(SVG_NS);
    }
  });

  it("returns a fresh element on every call", () => {
    const a = SVGIcon.render("copy")!;
    const b = SVGIcon.render("copy")!;
    expect(a).not.toBe(b);
    expect(a.isEqualNode(b)).toBe(true);
  });

  it("does not leak caller mutations into later renders", () => {
    const first = SVGIcon.render("score")!;
    first.classList.add("mutated");
    first.setAttribute("width", "99");
    first.removeChild(first.firstElementChild!);
    document.body.appendChild(first);

    const second = SVGIcon.render("score")!;
    expect(second.classList.contains("mutated")).toBe(false);
    expect(second.getAttribute("width")).toBe("16");
    expect(second.innerHTML).toBe(parsedMarkup("score"));
    expect(second.parentNode).toBeNull();
  });

  it("serializes cleanly for callers that need markup", () => {
    const html = SVGIcon.render("copy")!.outerHTML;
    expect(html.startsWith(`<svg xmlns="${SVG_NS}"`)).toBe(true);
    expect(html.endsWith("</svg>")).toBe(true);
  });
});
