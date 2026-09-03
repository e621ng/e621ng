<template>
  <template v-for="(group, gi) in renderGroups" :key="gi">
    <hr v-if="gi > 0">
    <div class="flex-wrap">
      <image-checkbox :check="check" :checks="selected" v-for="check in group"
                      @set="setCheck" :key="check.name"></image-checkbox>
    </div>
  </template>
</template>

<script>
  import checkbox from './checkbox.vue';

  const sex_names = {
    male: 'Male',
    female: 'Female',
    andromorph: 'Andromorph',
    gynomorph: 'Gynomorph',
    herm: 'Hermaphrodite',
    maleherm: 'Male-Herm',
    ambiguous_gender: 'Ambiguous'
  };

  const sex_checks = Object.entries(sex_names).map(([tag, name]) => ({ name, tag }));

  const sex_tag_keys = Object.keys(sex_names);
  const all_pairing_pairs = [];
  for (let i = 0; i < sex_tag_keys.length; i++) {
    for (let j = i; j < sex_tag_keys.length; j++) {
      all_pairing_pairs.push({ tagA: sex_tag_keys[i], tagB: sex_tag_keys[j] });
    }
  }
  const pairing_tag_name = tag => tag === 'ambiguous_gender' ? 'ambiguous' : tag;
  const all_pairing_tag_set = new Set(all_pairing_pairs.map(p => pairing_tag_name(p.tagA) + "/" + pairing_tag_name(p.tagB)));

  const char_count_checks = [
    {name: 'Solo'},
    {name: 'Duo'},
    {name: 'Trio'},
    {name: 'Group'},
    {name: 'Zero Pictured'}];

  const body_type_checks = [
    {name: 'Anthro'},
    {name: 'Feral'},
    {name: 'Humanoid'},
    {name: 'Human'},
    {name: 'Taur'}];

  export default {
    components: { 'image-checkbox': checkbox },
    inject: ['tagRegistry'],
    // "characters" = sex + count + sex-pairings; "body" = body types.
    props: { kind: { type: String, required: true } },
    data() {
      return { selected: {} };
    },
    computed: {
      pairing() {
        return this.kind === 'characters';
      },
      baseGroups() {
        return this.kind === 'characters' ? [sex_checks, char_count_checks] : [body_type_checks];
      },
      filteredPairings() {
        if (!this.pairing) return [];
        const selected = this.selected;
        return all_pairing_pairs
          .filter(p => selected[p.tagA] && selected[p.tagB])
          .map(p => ({
            name: sex_names[p.tagA] + "/" + sex_names[p.tagB],
            tag: pairing_tag_name(p.tagA) + "/" + pairing_tag_name(p.tagB),
          }));
      },
      renderGroups() {
        return this.pairing ? [...this.baseGroups, this.filteredPairings] : this.baseGroups;
      },
    },
    methods: {
      setCheck(tag, value) {
        this.selected[tag] = value;
        if (!value && this.pairing) {
          for (const p of all_pairing_pairs) {
            if (p.tagA === tag || p.tagB === tag)
              this.selected[pairing_tag_name(p.tagA) + "/" + pairing_tag_name(p.tagB)] = false;
          }
        }
      },
      // TagSource: the checked tags, with pairing tags only when both sexes remain selected.
      currentTags() {
        const self = this;
        const validPairingTags = new Set(this.filteredPairings.map(p => p.tag));
        return Object.keys(this.selected).filter(function (x) {
          if (!self.selected[x]) return false;
          if (all_pairing_tag_set.has(x)) return validPairingTags.has(x);
          return true;
        });
      },
      ownsTag(tag) {
        return typeof this.allChecks[tag] !== "undefined";
      },
      addTags(tags) {
        for (const tag of tags) this.setCheck(tag, true);
      },
      removeTag(tag) {
        this.setCheck(tag, false);
      },
    },
    created() {
      // Static ownership lookup for this instance's checkbox tags (non-reactive).
      const allChecks = {};
      const add = function (check) {
        if (typeof check['tag'] !== "undefined") allChecks[check.tag] = true;
        else allChecks[check.name.toLowerCase().replace(' ', '_')] = true;
      };
      this.baseGroups.forEach(group => group.forEach(add));
      if (this.pairing) all_pairing_tag_set.forEach(tag => { allChecks[tag] = true; });
      this.allChecks = allChecks;
    },
    mounted() {
      this.descriptor = {
        ownsTag: tag => this.ownsTag(tag),
        currentTags: () => this.currentTags(),
        addTags: tags => this.addTags(tags),
        removeTag: tag => this.removeTag(tag),
      };
      this.tagRegistry.register(this.descriptor);
    },
    beforeUnmount() {
      this.tagRegistry.unregister(this.descriptor);
    },
  };
</script>
