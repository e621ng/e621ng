<template>
  <template v-for="(group, gi) in renderGroups" :key="gi">
    <hr v-if="gi > 0">
    <div class="toggle-button-group">
      <image-checkbox
        :check="check"
        :model-value="!!selected[tagNameOf(check)]"
        v-for="check in group"
        @update:model-value="setCheck(tagNameOf(check), $event)"
        :key="check.name"
      ></image-checkbox>
    </div>
  </template>
</template>

<script setup lang="ts">
  import { reactive, computed, inject, onMounted, onBeforeUnmount } from "vue";
  import imageCheckbox from "./checkbox.vue";
  import { tagRegistryKey, type TagSource } from "./registry";

  interface Check { name: string; tag?: string; }

  const sex_names: Record<string, string> = {
    male: "Male",
    female: "Female",
    andromorph: "Andromorph",
    gynomorph: "Gynomorph",
    herm: "Hermaphrodite",
    maleherm: "Male-Herm",
    ambiguous_gender: "Ambiguous",
  };

  const sex_checks: Check[] = Object.entries(sex_names).map(([tag, name]) => ({ name, tag }));

  const sex_tag_keys = Object.keys(sex_names);
  const all_pairing_pairs: { tagA: string; tagB: string }[] = [];
  for (let i = 0; i < sex_tag_keys.length; i++) {
    for (let j = i; j < sex_tag_keys.length; j++) {
      all_pairing_pairs.push({ tagA: sex_tag_keys[i], tagB: sex_tag_keys[j] });
    }
  }
  const pairing_tag_name = (tag: string): string => (tag === "ambiguous_gender" ? "ambiguous" : tag);
  const all_pairing_tag_set = new Set<string>(all_pairing_pairs.map(p => pairing_tag_name(p.tagA) + "/" + pairing_tag_name(p.tagB)));

  const char_count_checks: Check[] = [
    { name: "Solo" },
    { name: "Duo" },
    { name: "Trio" },
    { name: "Group" },
    { name: "Zero Pictured" }];

  const body_type_checks: Check[] = [
    { name: "Anthro" },
    { name: "Feral" },
    { name: "Humanoid" },
    { name: "Human" },
    { name: "Taur" }];

  // "characters" = sex + count + sex-pairings; "body" = body types.
  const props = withDefaults(defineProps<{ kind: string; order?: number }>(), { order: 0 });

  const selected = reactive<Record<string, boolean>>({});

  const pairing = computed(() => props.kind === "characters");
  const baseGroups = computed<Check[][]>(() => (props.kind === "characters" ? [sex_checks, char_count_checks] : [body_type_checks]));
  const filteredPairings = computed<{ name: string; tag: string }[]>(() => {
    if (!pairing.value) return [];
    return all_pairing_pairs
      .filter(p => selected[p.tagA] && selected[p.tagB])
      .map(p => ({
        name: sex_names[p.tagA] + "/" + sex_names[p.tagB],
        tag: pairing_tag_name(p.tagA) + "/" + pairing_tag_name(p.tagB),
      }));
  });
  const renderGroups = computed<Check[][]>(() => {
    // Only append the pairings group when it has entries, so an empty pairings
    // set doesn't render a stray <hr> + empty row.
    if (pairing.value && filteredPairings.value.length)
      return [...baseGroups.value, filteredPairings.value];
    return baseGroups.value;
  });

  // Tag name for a checkbox (derivation formerly lived in checkbox.vue).
  function tagNameOf (check: Check): string {
    return check.tag || check.name.toLowerCase().replace(/ /g, "_");
  }

  function setCheck (tag: string, value: boolean): void {
    selected[tag] = value;
    if (!value && pairing.value) {
      for (const p of all_pairing_pairs) {
        if (p.tagA === tag || p.tagB === tag)
          selected[pairing_tag_name(p.tagA) + "/" + pairing_tag_name(p.tagB)] = false;
      }
    }
  }

  // The checked tags, with pairing tags only when both sexes remain selected.
  function currentTags (): string[] {
    const validPairingTags = new Set(filteredPairings.value.map(p => p.tag));
    return Object.keys(selected).filter((x) => {
      if (!selected[x]) return false;
      if (all_pairing_tag_set.has(x)) return validPairingTags.has(x);
      return true;
    });
  }

  // Static ownership lookup (non-reactive), built once.
  const allChecks: Record<string, boolean> = {};
  baseGroups.value.forEach(group => group.forEach(check => { allChecks[tagNameOf(check)] = true; }));
  if (pairing.value) all_pairing_tag_set.forEach(tag => { allChecks[tag] = true; });

  function ownsTag (tag: string): boolean {
    return typeof allChecks[tag] !== "undefined";
  }
  function addTags (tags: string[]): void {
    for (const tag of tags) setCheck(tag, true);
  }
  function removeTag (tag: string): void {
    setCheck(tag, false);
  }

  const registry = inject(tagRegistryKey)!;
  const descriptor: TagSource = {
    order: props.order,
    ownsTag,
    currentTags,
    addTags,
    removeTag,
  };
  onMounted(() => registry.register(descriptor));
  onBeforeUnmount(() => registry.unregister(descriptor));
</script>
