---
name: animation-gsap-motion
description: Production animation standards for Framer Motion and GSAP in React applications. Covers component enter/exit transitions, layout animations, stagger effects, GSAP ScrollTrigger timelines with useGSAP cleanup, and accessibility. Use when implementing interactive UI animations or scroll experiences.
---

# Animation Guide: Motion & GSAP for React

Production runbook for Framer Motion and GSAP in React applications.

## 1. Tool Selection Heuristic

- **Motion (Framer Motion)**: Default choice for React UI components, page transitions, modal dialogs, list re-ordering (`layoutId`), and hover/tap micro-interactions.
- **GSAP (GreenSock + ScrollTrigger)**: Use for complex multi-stage timelines, canvas manipulations, or pinning/scroll-scrubbed animations across multiple components.

---

## 2. Production Motion (Framer Motion) Patterns

### Accessible Staggered List with AnimatePresence
```tsx
import { motion, AnimatePresence } from 'framer-motion';

const containerVariants = {
  hidden: { opacity: 0 },
  visible: {
    opacity: 1,
    transition: { staggerChildren: 0.08, delayChildren: 0.1 },
  },
};

const itemVariants = {
  hidden: { opacity: 0, y: 12 },
  visible: {
    opacity: 1,
    y: 0,
    transition: { duration: 0.3, ease: [0.25, 1, 0.5, 1] },
  },
  exit: { opacity: 0, y: -8, transition: { duration: 0.15 } },
};

export function TaskList({ tasks }: { tasks: Array<{ id: string; title: string }> }) {
  return (
    <motion.ul variants={containerVariants} initial="hidden" animate="visible" className="space-y-2">
      <AnimatePresence mode="popLayout">
        {tasks.map((task) => (
          <motion.li key={task.id} variants={itemVariants} exit="exit" layout className="p-3 rounded-lg bg-zinc-900 border border-zinc-800 text-zinc-100">
            {task.title}
          </motion.li>
        ))}
      </AnimatePresence>
    </motion.ul>
  );
}
```

---

## 3. Production GSAP with `@gsap/react` (`useGSAP`)

Always clean up GSAP animations on unmount using the `useGSAP` hook:

```tsx
import { useRef } from 'react';
import gsap from 'gsap';
import { ScrollTrigger } from 'gsap/ScrollTrigger';
import { useGSAP } from '@gsap/react';

gsap.registerPlugin(ScrollTrigger);

export function HeroScrollSection() {
  const containerRef = useRef<HTMLDivElement>(null);
  const headlineRef = useRef<HTMLHeadingElement>(null);

  useGSAP(
    () => {
      const tl = gsap.timeline({
        scrollTrigger: {
          trigger: containerRef.current,
          start: 'top top',
          end: '+=800',
          scrub: 1,
          pin: true,
        },
      });

      tl.from(headlineRef.current, {
        scale: 0.8,
        opacity: 0,
        y: 40,
        ease: 'power2.out',
      });
    },
    { scope: containerRef }
  );

  return (
    <div ref={containerRef} className="h-screen flex items-center justify-center bg-black">
      <h1 ref={headlineRef} className="text-5xl font-bold text-white tracking-tight">
        Next Generation Engineering
      </h1>
    </div>
  );
}
```

---

## 4. Verification & Testing

Verify animation performance and cleanup:
1. **Render & Interaction Tests:**
   ```bash
   npm test -- TaskList.test.tsx
   ```
2. **Memory Leak / DOM Verification:** Ensure elements unmount cleanly and ScrollTrigger instances are killed on component teardown.
3. **Reduced Motion Check:** Test in browser with `@media (prefers-reduced-motion: reduce)` enabled.

---

## 5. Common Pitfalls & Negative Constraints

- **Never animate layout properties:** Do not animate `width`, `height`, `margin`, `top`, or `left`. Animate only GPU-accelerated `transform` (`x`, `y`, `scale`, `rotate`) and `opacity`.
- **Never create unscoped GSAP instances:** Always wrap GSAP timelines in `useGSAP` with a `scope` ref to prevent memory leaks.
- **Do not ignore accessibility:** Always provide fallback transitions for `prefers-reduced-motion`.
