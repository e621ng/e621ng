import { vi } from "vitest";

vi.mock("@/components/autocomplete", () => ({ default: { initialize_autocomplete: vi.fn() } }));
vi.mock("@/components/DTextFormatter.ts", () => ({ default: vi.fn() }));
vi.mock("@/utility/Toast", () => ({ default: { notice: vi.fn(), alert: vi.fn() } }));

import { afterEach, describe, expect, it } from "vitest";
import { mountUploader, unmountAll } from "./mountUploader";

afterEach(unmountAll);

// No source unmounts mid-session through the UI today, so this guards the
// coordinator mechanism directly: descriptors are stored raw (markRaw), so
// unregisterSource can match them by identity. Without markRaw the reactive
// proxy wrapping the pushed descriptor would never === the raw object the
// child holds, and the filter would remove nothing.
describe("uploads/uploader — source registry", () => {
  it("unregisterSource actually removes the descriptor", async () => {
    const { wrapper } = await mountUploader();
    const vm = wrapper.vm as any;

    const before = vm.registry.sources.length;
    expect(before).toBeGreaterThan(0);

    // The sink is an inline descriptor the root holds a raw reference to.
    vm.unregisterSource(vm.sinkDescriptor);

    expect(vm.registry.sources.length).toBe(before - 1);
    expect(vm.registry.sources.includes(vm.sinkDescriptor)).toBe(false);
  });

  it("re-registering after unregister restores the count (no proxy identity drift)", async () => {
    const { wrapper } = await mountUploader();
    const vm = wrapper.vm as any;

    const original = vm.registry.sources.length;
    vm.unregisterSource(vm.sinkDescriptor);
    vm.registerSource(vm.sinkDescriptor);
    expect(vm.registry.sources.length).toBe(original);

    vm.unregisterSource(vm.sinkDescriptor);
    expect(vm.registry.sources.length).toBe(original - 1);
  });
});
