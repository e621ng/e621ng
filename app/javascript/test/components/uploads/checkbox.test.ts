import { afterEach, describe, expect, it } from "vitest";
import { mount, VueWrapper } from "@vue/test-utils";
import Checkbox from "@/pages/uploads/new/checkbox.vue";

const wrappers: VueWrapper[] = [];
afterEach(() => {
  for (const w of wrappers.splice(0)) w.unmount();
});

function make (modelValue: boolean) {
  const wrapper = mount(Checkbox, { props: { check: { name: "Male", tag: "male" }, modelValue } });
  wrappers.push(wrapper);
  return wrapper;
}

describe("uploads/checkbox", () => {
  it("renders the check's name as the button label", () => {
    expect(make(false).find("button").text()).toBe("Male");
  });

  it("reflects modelValue via the active class", () => {
    expect(make(true).find("button").classes()).toContain("active");
    expect(make(false).find("button").classes()).not.toContain("active");
  });

  it("emits the negated value on click (controlled toggle)", async () => {
    const off = make(false);
    await off.find("button").trigger("click");
    expect(off.emitted("update:modelValue")!.at(-1)).toEqual([true]);

    const on = make(true);
    await on.find("button").trigger("click");
    expect(on.emitted("update:modelValue")!.at(-1)).toEqual([false]);
  });
});
