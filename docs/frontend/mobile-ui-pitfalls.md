---
title: Mobile UI traps that fail silently
summary: The styling, animation and canvas behaviours that produce a change which compiles, renders and is still wrong.
theme: frontend
keywords: [Pressable, functional style, class interop, active modifier, entering exiting, shared value, spring, timing, TextInput, lineHeight, Skia clipping, native rebuild, chart axes, context menu]
related:
  - frontend/mobile-stack-and-routing.md
  - frontend/mobile-widget-verification.md
  - frontend/typescript-react-conventions.md
---

## Functional style on Pressable is dropped

The utility-class interop layer intercepts the `style` prop and **drops a function**. Styles simply do not apply — no error, no warning.

```tsx
// BROKEN — styles will NOT apply
<Pressable style={({ pressed }) => [styles.container, pressed && styles.pressed]}>

// OK — visual styles on a child View, pressed effect via a class
<Pressable className="active:opacity-85" onPress={handlePress}>
  <View style={styles.container}><Text>Button</Text></View>
</Pressable>

// OK — the active: modifier
<Pressable className="bg-primary active:bg-primary/85 flex-row rounded-full px-4 py-2">
```

**Rule: never pass a function to `Pressable`'s `style` prop.** Use the active-state modifier, or move visual styles to a child view.

## Animation patterns

Preferred — declarative entering/exiting:

```tsx
<Animated.View entering={FadeInUp.delay(100).duration(300)} exiting={FadeOut}>
```

Controlled — a shared value driving a derived style:

```tsx
const progress = useSharedValue(0)
progress.value = withTiming(isExpanded ? 0 : 1, { duration: 250 })

const animatedStyle = useAnimatedStyle(() => ({
  opacity: interpolate(progress.value, [0, 1], [0, 1]),
  height: interpolate(progress.value, [0, 1], [0, 230], Extrapolation.CLAMP),
}))
```

Anti-patterns:

- Never mix the modern animation library with the legacy animated API in one component.
- Never use the native animation library in the web app — the web animation library belongs there.
- Animations over 500ms for UI feedback are too slow.

## Spring versus timing

Spring for scale and position, because they have physical analogues. Timing for opacity, colour and progress, which do not.

```typescript
transform: [{ scale: withSpring(isActive ? 1 : 0.9, { damping: 15, stiffness: 150 }) }]
withSpring(BOUNCE_HEIGHT, { damping: 4, stiffness: 200, mass: 0.5 })
opacity: withTiming(isVisible ? 1 : 0, { duration: 300 })
```

## Shared animated components

The shared UI package exports a preset-driven animated view, a staggered variant for lists, and a pressable with spring press feedback.

The animated pressable does **not** include haptics — call the haptics helper yourself. Visual feedback without the tactile half reads as lag on a physical device.

## Never use a raw text input in a screen

Use the shared input component. It fixes padding quirks, descender clipping and height jumping that the platform primitive exhibits by default, and its variant prop selects the container shape.

**Never apply text-size or line-height utility classes to a text input** — they conflict with the platform's own line-height handling and reintroduce the clipping the component exists to fix.

## Canvas graphics

```typescript
const x = useSharedValue(0)      // shared values bind directly to canvas props
<Circle cx={x} cy={100} r={10} color="orange" />
```

- **The canvas clips to its bounds**, unlike SVG, which allows overflow. Budget padding for glow and blur radius or they are cut off.
- **A native rebuild is required** after installing it — a clean prebuild plus a native run. The managed dev client does not carry it.
- The chart library built on the canvas takes it as a peer dependency. Disable the default frame by passing a zero line width; **omit** the axis props rather than passing null, which is a type error.

## Context menus

The wrapper renders the platform-native menu on each OS — a blurred native menu on one, a popup menu on the other. No config plugin is needed. Wrap the trigger in a plain view if the styling interop conflicts.

## The general pattern

Every trap on this page shares a shape: **the change compiles and renders, and the wrong thing happens quietly.** A dropped style prop, a clipped canvas, a stale native module and a conflicting line-height all produce a screen that looks plausible.

Verify a visual change by observing a consequence that changes on its own — see the widget verification doc for the full form of that rule.
