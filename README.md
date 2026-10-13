# VizHelper

## Installation

Go to releases and download the latest version.
Windows only (but ill try to get it working on Mac/Linux) otherwise use Wine.
If it crashes with a missing dll error, install the latest [Visual C++ Redistributable](https://learn.microsoft.com/en-us/cpp/windows/latest-supported-vc-redist?view=msvc-170)

## Usage

Use with [Viz2.0](https://github.com/playsamay4/Viz2.0)

## Changes in this fork

Fork of [playsamay4/VizHelper](https://github.com/playsamay4/VizHelper). It needs the matching fork of Viz2.0 for these to do anything.

- **Live Bug Control:** a *Side* box (Left / Right) picks the screen edge of the LIVE bug.
- **Aston Control, Breaking Strap:**
  - Only the top line is required for *Show/Update Strap*. Leave *bottom line (1/2)* blank for a single line breaking strap, and *(2/2)* blank if the second line should not scroll (`NOP` still works).
  - *Show/Update BREAKING* and *Show/Update Strap* change the text of a strap that is already on air without taking it down. *Scroll BREAKING* and *Hide Strap* no longer ask for fields they do not use.
- The one line *Text Strap* no longer raises the white ticker with it (that is done in Viz2.0, nothing to set here).
- **Title Control** (was Tile Control): *Titles (BBC News, Chameleon)* shows the new BBC blocks title, the red boxed BBC NEWS logo is under *Legacy titles (Red boxed BBC News Logo)*.
- **Testing area:** buttons for what Viz2.0 only does from a keyboard shortcut (wipe, ticker only, clock, breakfast clock, backdrop, Gill Sans mode, hide splash, scaled window).
- **Headline Control** is one line only, and the *No BBC NEWS box* and *Look North Viz Style* options are gone. **Playout Control** and **Automation** are gone too.
- **Branding Control:** *Send Branding* now sends the real *Opaque ticker* value (it sent the checkbox object, so the viz always showed the transparent ticker) and the *Clock mode*.
- The BREAKING title in the Breaking Strap tab is optional.
- Bad answers from the RSS server no longer crash the helper at startup (the old `http://rss.playsamay4.com:2082` address now answers with a redirect to HTTPS, which the helper cannot follow, so the *BBC RSS feeds* option has no headlines until that is dealt with).

## License

VizHelper is licensed under the [GNU General Public License v3.0](LICENSE).