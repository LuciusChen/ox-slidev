---
title: Official Style Showcase
author: Slidev-inspired
theme: seriph
class: text-center
background: 'https://cover.sli.dev'
transition: slide-left
COMARK: true
---

# Welcome

Press Space for next page <carbon:arrow-right class="inline-block" />
Inline badge <Badge type="warning">Beta</Badge>


<div @click="$slidev.nav.next" class="mt-12 py-1" hover:bg="white op-10">

Press Space for next page

</div>


<Link href="https://sli.dev" target="_blank">

Slidev Docs

</Link>

---
transition: fade-out
---

# Animations

<v-clicks at="2">

-   Text-based
-   Themable
-   Interactive

</v-clicks>


<div v-after="3">

After click hint

</div>

---
layout: two-cols
layoutClass: gap-16
---

# Two Cols

You can generate table of contents with components.


::right::


<Toc text-sm minDepth="1" maxDepth="2" />

---

# Motion

<Arrow x1="350" y1="310" x2="195" y2="342" color="#953" width="2" arrowSize="1" />


<div v-drag="[120,140,220,auto]" class="w-40 opacity-80">

Draggable note

</div>


<Transform scale="0.9">


<Tweet id="1894208196031267235" scale="0.8" />

</Transform>


<Youtube id="dQw4w9WgXcQ" width="320" height="180" />


<LightOrDark>


<template #light>

Light mode helper

</template>


<template #dark>

Dark mode helper

</template>

</LightOrDark>


<PoweredBySlidev />

---
layout: image-right
image: 'https://cover.sli.dev'
---

# Gallery

Image layout wrapper with centered caption

---

# Code

```ts {all|2|4}
import { ref } from 'vue'

const count = ref(0)
```
