---
title: Research Update
author: Team Ox
theme: seriph
DRAWINGS: false
layout: cover
class: px-14
---

# Opening

Research Update

From Org source to a talk-shaped Slidev deck

---

# Agenda

<v-clicks at="2">

-   Problem framing
-   Working assumptions
-   Key result
-   Rollout steps
-   Delivery plan

</v-clicks>


<!--
Set the context before showing details.
-->

---
layout: two-cols
layoutClass: gap-12
---

# Problem

We want a deck authoring workflow that stays readable in Org and still exports
to modern Slidev features.

-   Plain Org should stay useful
-   Slide-specific syntax should stay explicit
-   Review output should be predictable


::right::


<div v-after="2">

Current friction drops when one source can serve writing, review, and demo.

</div>

---

# Signals

The workflow is useful when the review surface gets smaller without losing
Slidev-native features.

| Signal | Before | After |
| :--- | :--- | :--- |
| Review unit | Org + hand-edited md | One Org source |
| Preview loop | Export and inspect | Export, then Slidev HMR |
| Final output | Inconsistent markdown | Stable golden + demo |

See the current reference demo at [sli.dev](https://sli.dev) for the target
feel, not the source format.

---
layout: image-right
image: 'https://cover.sli.dev'
---

# Result

The exported deck preserves math and ordinary content.

Inline result: $f(x) = x^2 + 1$

$$
\int_0^1 x^2 dx = \frac{1}{3}
$$

---

# Rollout

<v-clicks at="2">

1.  Keep most slides as plain Org.
2.  Use explicit Slidev blocks only for repeated visual structure.
3.  Lock output with fixture tests before polishing themes.

</v-clicks>


<!--
The point is predictable authoring, not maximum abstraction.
-->

---

# Example

```emacs-lisp {1|3}
(setq org-slidev-open-browser t)
(message "export -> preview -> review")
```

---

# Takeaway

-   Org stays the writing format.
-   Slidev stays the runtime format.
-   The exporter keeps the mapping explicit and reviewable.

---
layout: quote
---

# Close

Readable Org first, Slidev power when it is justified.
