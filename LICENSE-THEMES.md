# Themes, theme files, and what you may share

This repository is MIT (see [LICENSE](LICENSE)). That covers the scripts.

A theme file that a script *generates* is not automatically ours to license,
because a `.ReaperTheme` is mostly other people's work carried along by our
colours. This file says, plainly, what you can do with those files and what you
need to carry with them.

## The short version

- **Colour values our script writes:** MIT. Yours to keep, change, publish, sell.
- **Everything it inherited from the theme you had loaded** (the other colour
  keys, the fonts, the images referenced by `ui_img`): still that theme's, under
  that theme's licence.
- **If you want to share a theme without any obligations:** make it from
  REAPER's stock Default theme. Then the inherited parts are Cockos's, and
  REAPER's licence terms are far more permissive than most theme licences.

## Why this matters

The script does not create a theme from nothing. It reads the theme REAPER
currently has loaded, replaces ~33 colour keys with our palette, and writes the
result back out with everything else untouched — including the `ui_img` that
points at that theme's images and the font blobs in `[REAPER]`.

That is the right way to do it (a colour file with no image stack looks broken),
but it means the output is a **derivative** of the source theme. If the source is
GPL-3.0, so is the file you just made from it.

This is not hypothetical. Commonly shared REAPER themes include GPL-3.0 ones,
ones with no licence at all (which means all rights reserved, not "free"), and
many distributed as `.ReaperThemeZip` files with a licence note that lives only
in a forum thread. If you publish a recolour of one of those, you are publishing
their artwork.

## What you may do

| You want to... | Do this |
|----------------|---------|
| Use a generated theme in your own sessions | Go ahead. No conditions. |
| Give a generated theme to a friend | Fine, with the provenance note that the script now writes into the file header. |
| Publish a generated theme | Check the source theme's licence first. The file header records it as `Derived from: <theme>`. |
| Publish a theme with no obligations | Rebuild from REAPER's Default theme, so nothing is inherited from a third party. |
| Sell a theme you built with this script | Only for the parts that are yours. If it contains someone else's artwork, their licence decides. |
| Copy the script into your own project | MIT: do it, keep the notice, no other conditions. |

## What the script does to help

- It **refuses** to edit a `.ReaperThemeZip`. That is partly a technical limit
  (the colours are inside the zip) and partly so it cannot quietly produce a
  recolour of artwork it cannot see.
- It writes a **provenance header** into every generated file: the colour values
  are MIT, the file names the theme it was derived from, and the header says in
  as many words that inherited artwork keeps its own licence.
- It **preserves leading `;` comments** from the source theme, so an author's own
  attribution lines survive instead of being dropped.

## If you are a theme author and want this project to stay away from your work

Open an issue. Nothing in this repository contains any theme's artwork, and the
one place a theme file appears at all is `tests/fixtures/theme_sample.ReaperTheme`,
which is generated from REAPER's documented stock defaults: every colour set to
`0`, no images, no font blobs, no author's content. It exists so the parser has
something in the right format to read.

## What this file is not

It is not legal advice, and it is not a licence of its own — it does not add to
or subtract from the MIT terms in [LICENSE](LICENSE). It is an explanation of
which licence applies to which part of a generated file, so that nobody has to
guess.
