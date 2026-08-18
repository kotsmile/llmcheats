---
title: Home-screen widgets — constraints and verification gates
summary: Why a widget layout has no module scope, the three verification gates each blind to the next one's failure, and the empty-state design rule they exposed.
theme: frontend
keywords: [home screen widget, widget extension, babel plugin, source string, app group, cold start, fast refresh, prebuild, simulator, screenshot diff, empty state, spacer, slack sink]
related:
  - frontend/mobile-ui-pitfalls.md
  - frontend/mobile-stack-and-routing.md
---

## The constraint

A widget layout is a function carrying a directive string. A build plugin replaces it with **a string of its own source**, stored in a shared app-group container at app start.

Three consequences follow directly:

- It has **no module scope**. Every value comes from props or from a global the extension provides.
- A source edit reaches the extension only through a **cold start**, never through hot reload.
- A native prebuild is needed **only** when the app config changes, because the extension list is native. Layout and builder edits ride the ordinary bundler.

## Three verification gates

Each gate is blind to the failure the next one catches. Skipping any produces a screenshot that looks like proof and is not.

```bash
DEV=<simulator udid>

# 1. Launch on a live process — launch alone only foregrounds an existing one
simctl terminate $DEV <bundle-id>
simctl launch    $DEV <bundle-id>

# 2. Wait for the layout hash in the app-group preferences to CHANGE.
#    A stale bundle re-registers the old source and the file's mtime still moves,
#    so mtime is not the signal — the hash is.
simctl terminate $DEV <bundle-id>

# 3. Shoot until the widget rectangle differs from the last accepted frame.
#    The widget host redraws on its own schedule, so a fresh layout can render an old picture.
```

**Gate 3 has no ready-made command and is therefore the one that gets skipped.**

Crop to the widget's own rectangle before diffing. A full-screen comparison reports "changed" because the wallpaper shifted behind a rounded corner.

The app-group preferences file lives under the simulator device's shared container directory.

Appearance and text size for the check matrix are set through the simulator's UI subcommands (light/dark, and the dynamic-type range up to the accessibility sizes).

## The rule behind all three

**An observation counts only if it has a consequence that changes on its own.**

A command's own answer does not qualify. Setting a dynamic-type size can report success while the setting never applied, and repeated changes can wedge the simulator into serving one frozen frame — cured by a shutdown and boot, not by retrying.

Byte-identical pixels across states that should differ are the tell.

## A signal must be carried by something that exists at zero

Four separate widget defects turned out to be one mistake:

- a bold `0` standing in for "no value yet";
- a time range shown on a window that had already closed;
- a category's brand colour living only in the *filled* portion of a gauge;
- a header's trailing metadata collapsing to an ellipsis when the title took the width.

Each encoded meaning in something the empty state does not have — a fill, a number, leftover width. The design read correctly with data and lied without it, **which is the state a new user sees first**.

A coloured dot is always there. A fill may not be.

## A trailing spacer is not a bottom margin

A single trailing spacer pins the stack to the top and hands every unused point to the foot. One widget measured 16pt above its content and 32pt below, which reads as a card sitting crooked.

- **Where the card has a footer row**, push the spacer *before* it: both margins stay the system value and the slack becomes a seam that says "different question".
- **Where there is no footer**, the trailing spacer is correct. Centring the block instead pulls the top element off the edge, and the resulting margins no longer match the widgets beside it.
