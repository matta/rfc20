---
title: "Please Respect My Browser Font Size"
date: 2022-10-04T09:44:52-07:00
tags: []
draft: false
---

*TLDR*: Hard coding font sizes in `px` units makes your site hard for me to
read.  Consider basing your sites font sizes off the user's default font
size, especially for the main body content.

## The problem

I have a moderate astigmatism and can no longer read tiny text like I used
to, when wearing single purpose "computer glasses."  I also have a laptop
with a small and relatively high resolution screen.  On this machine I've
adjusted Firefox's default font size to `20px`, which makes body text easy
for me to read.

Yet, many websites override this and hard code body text to something like
`16px` or, worse, `14px` or even `9px`!

## Easy solution

Fortunately, browsers worth considering today support a simple solution:
use `rem` units instead of `px`.  Or, use some other approach that bases
the font size off the user's default font size, which is the `font-size` of
the [`:root` CSS
pseudo-class](https://developer.mozilla.org/en-US/docs/Web/CSS/:root).

See the Mozilla [MDN on
font-size](https://developer.mozilla.org/en-US/docs/Web/CSS/font-size), which says:

> **Note**: To maximize accessibility, it is generally best to use values
> that are relative to the user's default font size.

One viable choice is leaving `font-size` entirely alone in your site's CSS,
at least in styles that apply to body text.  This is what the MDN does in
its own site, and the browser shows me a nice `20px` font in body text.

**Recommendation**: visit
https://developer.mozilla.org/en-US/docs/Learn/CSS and see if you like the
body text size there.  If so, just go with it!  Stop setting `font-size` at
all for body text in your site.  The MDN doesn't.

Another choice is using `rem` units, A `rem` is a multiplier against the
font size set on the [`:root` CSS
pseudo-class](https://developer.mozilla.org/en-US/docs/Web/CSS/:root),
which, unless your site's CSS changes it, is the users chosen default font
size.  All browsers today default this setting to `16px`, but people can
choose to make it larger by adjusting their browser settings.

One site which I consistently find quite readable is [The New York
Times](https://www.nytimes.com/), which uses this relatively simple way of
setting font size for body text:

```css
.body-text {
  font-size:1.125rem;
  line-height:1.5625rem;
}
@media (min-width:740px) {
  .body-text {
    font-size:1.25rem;
    line-height:1.875rem;
  }
}
```

The `body-text` class applies to article body text.  (Note: I've renamed
the class to "`body-text`" here from the cryptic name they actually use on
the site.)  The CSS above, by default, sets body text to `18px` (`1.125rem`
⇔ `16px` * `1.125` ⇔ `18px`) on narrower windows and `20px` (`1.25rem` ⇔
`16px` * `1.25` ⇔ `20px`) on larger ones.  Because my default body text is
set larger than `16px` the formulas above scale body text even larger,
which is great for me.  You can see they use a similar trick for
`line-height`.  The combined effect is body text that is slightly larger
and more spaced out than the default, which is great for reading articles
quickly.

A site that does this comparatively poorly is [Washington
Post](https://www.washingtonpost.com/).  You can see that they scale by
roughly the same `rem` multipliers, but *they override my chosen default
font size* by hard coding a `16px` baseline:

```css
:root {
    /* BAD: this overrides my font size preference! */
    font-size:16px
}
.font-copy {
    font-size:1.125rem
}
@media only screen and (min-width:1024px) {
    .font-copy {
        font-size:1.25rem
    }
}
@media only screen and (min-width: 768px) and (max-width: 1023px) {
    .font-copy {
        font-size:1.25rem
    }
}
.font--article-body {
    line-height:1.6
}
```

## Examples of sites doing it well

[New York Times](https://www.nytimes.com/)
: see above

[Python Docs](https://docs.python.org/3/)
: These pages set the `font-size` to `100%` for the `<body>` tag.
  Percentages are relative to the parent element's font size.  In this case
  the `font-size` of `:root` and `<html>` are left at the default.  Of
  interest, these docs are generated with
  [Sphinx](https://www.sphinx-doc.org), whose own site doesn't set
  `font-size` at all, with the same effect.

[Beautiful Racket](https://beautifulracket.com/)
: Uses a body text of `1em`, respecting the user's default.

## Examples of sites doing it not so well

[Hacker News](https://news.ycombinator.com/)
: Sets text to `9px` -- almost half the browser default for body text!  I
  have to zoom that site out 200%.

[Lobsters](https://lobste.rs/)
: As bad as Hacker News, for the same reason.  What is it with these sites?
  My guess: they're developed by people with *great* eyesight!

[Reddit](https://www.reddit.com/)
: Sets text to `14px`, a touch smaller than browser defaults.  I zoom
  Reddit to 150%.

[Racket Documentation](https://docs.racket-lang.org/)
: Much like the Washington Post, these pages hard code the font to `15px`.
  This is smaller but close to the browser default, so few people notice,
  but I usually need text to be 25% larger.  The site then scales body text
  up by `1.18rem` which gives me a `17.7px` font.  So, the designer here
  clearly wanted something larger than default, but perhaps inadvertently
  defeated my desire to have text that was even larger.

[Facebook](https://www.facebook.com/)
: For unknown reasons Facebook scales post text with `.9375rem`, reducing
  my preferred font size of `20px` to `18.75px`.  Not terrible, but why
  base a site's font size off the browser default but *reduce* it?  It is
  almost as if reading comprehension isn't the point of Facebook.

## What about browser zoom?

From personal experience: tweaking zoom every time I visit a new site is a
drag.

Also, zoom scales *everything*, including spacing around icons, etc.  I
generally only want larger main *body text*, not larger *everything*.

## What about the viewport meta tag?

You might have noticed that many sites include the following incantation in
their `<head>` tag nowadays:

```html
<meta name="viewport" content="width=device-width,initial-scale=1"/>
```

See the [description on Mozilla's
MDN](https://developer.mozilla.org/en-US/docs/Web/HTML/Viewport_meta_tag)
for the full scoop.  Longs story short, this is an incantation that tells
the browser that the page's CSS is designed to be "responsive" to the small
screens typical of mobile devices.  The `initial-scale=1` portion opts in
to a browser heuristic where even `px` sizes are heuristically scaled
larger based on the DPI of the device's screen.  This generally works
pretty well.  But, this heuristic is typically not used by desktop
browsers.

## What about magic/intelligent DPI handling on the host OS?

In theory, the browser and the host the OS font system will have perfect
knowledge of the physical size of the screen, the pixel density (DPI), and
the user's preferred text size, and make intelligent choices based on all
of these factors.  For mobile, this is essentially what the `viewport` meta
tag is all about.  For desktop browsing the browser's default font size is
still the most reliable way to size a font that the user will be happy
with.

## Recommendation: use `rem` or nothing at all

When I come across a site that respects my browser's default font size it
most often takes one of two approaches:

1) It does not set a font size at all.  Simpler sites take this option quite often.

2) It uses `rem` instead of `px`.  Sites with more complex CSS and fancier
layouts seem to do this.

Less often, the site uses percentages or font sizes like "smaller."  Take a
look at one of the *relative* font size approaches [that are standardized
and widely supported
today](https://developer.mozilla.org/en-US/docs/Web/CSS/font-size) and use
them.  Your readers will be happier for it!
