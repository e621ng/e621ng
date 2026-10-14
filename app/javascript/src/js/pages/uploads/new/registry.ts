import type { InjectionKey } from "vue";

// A tag source registered with the uploader's coordinator. The uploader aggregates
// every source's `currentTags()` (in `order`) and routes inbound tags to the owning
// source (`ownsTag`) / role (`role`) / the sink (`isSink`).
export interface TagSource {
  order: number;
  currentTags(): string[];
  addTags(tags: string[]): void;
  removeTag(tag: string): void;
  role?: string; // routeByRole target (artist / character / species / content)
  isSink?: boolean; // the always-present "Other Tags" catch-all
  ownsTag?(tag: string): boolean; // value routing (checkbox sources)
}

export interface TagRegistry {
  register(source: TagSource): void;
  unregister(source: TagSource): void;
}

// Typed provide/inject key, replacing the untyped string `tagRegistry`.
export const tagRegistryKey: InjectionKey<TagRegistry> = Symbol("tagRegistry");
