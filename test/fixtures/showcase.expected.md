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

Inline status <Badge type="warning">Internal Preview</Badge>

---

# Agenda

<v-clicks at="2">

-   Problem framing
-   Working assumptions
-   Key result
-   Implementation shape
-   Feedback and rollout
-   Rollout steps
-   Delivery plan

</v-clicks>


<!--
Set the context before showing details.
-->

---
layout: center
---

# Deck Map

This deck stays mostly plain Org and only uses explicit Slidev mappings where
they improve the presentation.


<Toc text-sm minDepth="1" maxDepth="2" />

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


<!--
Pause on the review loop row. That is the real adoption win.
-->

---
layout: center
---

# Workflow Map

The practical loop is simple:

Org draft <carbon:arrow-right class="inline-block" /> export
<carbon:arrow-right class="inline-block" /> Slidev preview
<carbon:arrow-right class="inline-block" /> review


<Arrow x1="160" y1="280" x2="540" y2="280" color="#0f766e" width="3" arrowSize="1" />


<div class="mt-8 rounded border border-main px-4 py-3 text-sm">

One source file serves drafting, code review, and live presentation.

</div>


<div v-drag="[420,80,220,auto]" class="rounded bg-white/80 px-3 py-2 text-xs shadow">

Reviewer note: markdown output remains hand-auditable.

</div>

---
transition: fade-out
---

# Early Feedback

The early reaction is strongest when the authoring surface stays small.


<Transform scale="0.9">


<Tweet id="1894208196031267235" scale="0.8" />

</Transform>


<!--
Use this as a stand-in for real team feedback until we have our own examples.
-->

---

# Demo Clip

The deck is useful only if the preview loop is short enough to use during
editing.


<Youtube id="dQw4w9WgXcQ" width="640" height="360" />


<Link href="https://sli.dev" target="_blank">

Slidev reference

</Link>

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

The output still reads like markdown instead of generated noise.[^readable]


[^readable]: This matters because exported files remain reviewable in pull requests.

---

# Theme Check

This deck should remain readable in either theme.


<LightOrDark>


<template #light>

Light mode keeps the explanatory slides clean and presentation-first.

</template>


<template #dark>

Dark mode is useful for code-heavy or demo-heavy sections.

</template>

</LightOrDark>

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


<PoweredBySlidev />
