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
-   Key result
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

# Example

```emacs-lisp {1|3}
(setq org-slidev-open-browser t)
(message "export -> preview -> review")
```

---
layout: quote
---

# Close

Readable Org first, Slidev power when it is justified.
