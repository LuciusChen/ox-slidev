---
title: Edge Cases
author: Team Ox
theme: seriph
---

# Escape Hatch

This slide shows the boundary where raw Slidev or Vue is the right choice.

<MyWidget
  :items="items"
  v-if="$slidev.nav.currentPage >= 2"
  class="mt-6"
/>


<!--
Do not build a new Org DSL for one-off Vue expressions.
-->

---
layout: two-cols
---

# Default Slot

Use the unnamed slot only when the layout really exposes a default region.


::default::

This content goes through the explicit \`default\` slot path.


::right::

Supporting detail stays in the right slot.

---

# Markdown Passthrough

This slide uses \`markdown\` passthrough when the target syntax is already the
clearest form.

> Raw markdown stays available when that is the lowest-friction option.


<MyWidget data-id="alpha-1" data-state="ready">

Custom component blocks remain available for uncommon but readable cases.

</MyWidget>
