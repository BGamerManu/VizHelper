# VizHelper (BGamerManu fork)

The control panel for [Viz2.0](https://github.com/BGamerManu/Viz2.0). It is a [LÖVE](https://love2d.org/) + Dear ImGui program that sends requests to Viz2.0 over the network.

Fork of [playsamay4/VizHelper](https://github.com/playsamay4/VizHelper), made and maintained by Manuel_Ottani. I am trying to keep it updated as far as I can. **It needs the matching fork of Viz2.0**, otherwise the new controls do nothing.

![VizHelper hub](docs/images/hub.png)

## Installation

1. Download the latest Windows zip from [Releases](https://github.com/BGamerManu/VizHelper/releases). LÖVE 11.4 is inside: unzip it and run `avvia-helper.bat`.
2. Start Viz2.0 first (from the [Viz2.0 release](https://github.com/BGamerManu/Viz2.0/releases)), then VizHelper. The *Connect to Viz2.0* button turns green when they are connected. If Viz2.0 is on another computer, set its IP in the settings (gear icon).
3. Windows only. If it crashes with a missing dll error, install the latest [Visual C++ Redistributable](https://learn.microsoft.com/en-us/cpp/windows/latest-supported-vc-redist?view=msvc-170).

## The windows

| Button | What it does |
|---|---|
| **Aston Control** | Text strap, Breaking strap, Name strap, Programme badge, other badges, News Bar show / hide |
| **Ticker Control** | Ticker text and its default text, RSS feeds of many providers, list editor, ON/OFF buttons |
| **Branding Control** | Channel name, theme colour, separate BREAKING accent colour, custom logo, opaque ticker, coloured straps, clock mode, saved brandings |
| **Headline Control** | One line headline with an optional COMING UP box |
| **Title Control** | Chameleon title (BBC blocks) and the legacy red boxed BBC NEWS logo (locked while a custom logo is set) |
| **Live Bug Control** | LIVE bug with place, optional time and offset, side Left / Right / **Both** |
| **Testing area** | Buttons for testing Viz2.0: wipe, ticker only, clock, backdrop, scaled window |

## Aston Control

### Text Strap

![Text strap tab](docs/images/aston-text.png)

A top line is required. Leave *bottom line (1/2)* blank for a one line strap and *(2/2)* blank if the second line should not scroll (`NOP` still works). The last box is the small tag next to the BBC NEWS box (here *IN BRIEF*).

*Show/Update Strap* changes the text of a strap that is already on air, **also from one line to two lines and back, without taking the strap down**.

### Breaking Strap

![Breaking strap tab](docs/images/aston-breaking.png)

- An optional BREAKING headline (*Show/Update BREAKING*, then *Scroll BREAKING* moves between BREAKING and its headline).
- The same one / two line text as the text strap (*Show/Update Strap*).
- **Text strap ⇄ breaking strap never lowers the graphic**: the red BREAKING box and tag come up over the strap, or sink away again. If the text is identical only the red box is added or removed, otherwise the text rolls too.

### Programme Badge

![Programme badge tab](docs/images/aston-badge.png)

Pick a preset in the list (it scrolls), or type a text and colours, then *Show Badge*. *Save badge* adds yours, *Remove selected badge* deletes the selected one.

Presets: ACROSS THE UK, WORLD NEWS TODAY, THE WORLD TODAY, NEWS NOW, THE CONTEXT (red on white), THE CONTEXT USA, BUSINESS TODAY, NEWSROOM LIVE, AFTERNOON LIVE, NEWSDAY, GLOBAL, NICKY CAMPBELL, FOCUS ON AFRICA, G M T, SPORTSDAY, YOUR QUESTIONS ANSWERED. They live in `badges.dat` in the save folder (`%APPDATA%\LOVE\VizHelper`): delete it to get the default list back.

## Branding Control

![Branding Control](docs/images/branding.png)

The program always starts with **News Red Straps** (selected in the list) and sends it to Viz2.0 as soon as it connects, and again when it reconnects. The window is closed at startup: open it to pick another saved branding or to save your own. *Send Branding* sends what the boxes say, including the real *Opaque ticker* value and the *Clock mode*.

### Graphics style: Election 24 Viz - Experimental

*Graphics style* in Branding Control (and the saved branding **Election 24 Viz - Experimental**) switches Viz2.0 to a second look, taken from the BBC Election 2024 graphics ([video](https://youtu.be/30-SS2-rtIk)) and adapted to the branding: the name is the channel name (BBC NEWS, not BBC Election) and the colours are the ones of the branding (the saved branding uses the red of the BREAKING graphics of the video, `#B10000`).

- **News Bar**: a header (BBC logo and the channel name) on top of a white bar with a small square and the ticker text, and the clock box on the right.
- **Straps** (Text Strap, Name Strap, Breaking Strap): the strap opens **between the header and the bar**, the header rides up with it. The header is the strap colour at 59%, the body fades slightly towards its bottom, the BREAKING strap is one flat colour. Two lines are title and line under it, or name and job. The box text (or BREAKING) is a white tag in the header.
- **Animations** (timed on the video): a strap that changes fades its text out (0.2 s), changes colour (0.25 s) and fades the new text in; BREAKING rolls up behind the header and the white BREAKING tag is wiped in before the headline fades in (*Scroll BREAKING* goes back the same way).
- **LIVE bug** (Left / Right / Both), which opens and closes from its bottom edge, and **Headline** (a tag and a large headline that roll up). A headline takes the place of the News Bar, as in the classic graphics.
- Programme badges, the other badges and the breakfast clock are not drawn in this style; the vote panels of the election graphics are not included.
- A custom logo (see below) replaces the BBC logo in the header and in the headline tag.

### Breaking accent colour

Tick *Separate from the theme colour* to give the BREAKING graphics (red BREAKING box and tag of the strap, BREAKING items of the ticker) a colour of their own. Untick it and they keep the red they always had. It is saved with the branding.

### Custom logos

*Custom logos...* replaces the BBC logo in the News Bar and in the headline box with an **SVG** (only SVG: it is drawn by VizHelper and recoloured by Viz2.0).

- **From a file**: type the path of an `.svg` and press *Load SVG*, or drop the file on VizHelper.
- **Search online**: pick a broadcaster in the list (or type a name) to search SVG logos on Wikimedia Commons, click a result to use it. Logos are trademarks of their owners.
- **Colour**: *Original colours* keeps the colours of the SVG, *One colour* paints the whole logo with the colour you pick, *Automatic* paints it black or white, whichever reads on the graphic it is over. One colour and Automatic need a logo that is a plain shape: a logo with a solid box behind it becomes a solid box.
- The logo is sent and saved with the branding (*Send Branding* / *Save branding*). *Back to the BBC logo* undoes it.
- **While a custom logo is set the Title Control is locked**, because the titles are BBC graphics.
- Not drawn: text (use logos whose letters are outlined), images, filters, masks and clip paths. Gradients are painted with their average colour.

## Headline Control

![Headline Control](docs/images/headline.png)

Headlines are one line. A long one is shrunk and then **squashed sideways to stay on screen**, and the BBC NEWS box and the vertical bar follow the height of the text. *Coming Up badge* adds the COMING UP box.

## Ticker Control

With *My text* build the ticker as a list: each row is a label (HEADLINES / BREAKING / INTERACTIVE) or a text, with Up / Dn / X buttons, and the *+* buttons add a row (with its label when needed). *Apply to ticker* puts it on air and saves it for the next start. With *RSS feed* the list picks the provider: BBC News UK, BBC World, BBC Top Stories, Sky News, The Guardian, Al Jazeera, DW, France 24, NPR, The New York Times, ANSA, la Repubblica. *Show at most* cuts the number of headlines.

## Title Control

![Title Control](docs/images/title.png)

The **Chameleon** title writes **NEWS** under the BBC blocks, or **WORLD NEWS** if the channel name of the branding has "world" in it. The red boxed BBC NEWS logo is under *Legacy titles*.

## Live Bug Control

![Live Bug Control](docs/images/livebug.png)

*Location* is the place, *Live* adds the LIVE box, *Show Time* adds a clock (with an hour offset). **Side** is Left, Right or **Both**: with Both the bug is shown on each side of the screen at the same time (the right one is the mirror image of the left one).

## Testing area

![Testing area](docs/images/testing.png)

Testing buttons for Viz2.0: wipe transition, ticker only, clock, backdrop and scaled window.

## Changes in this fork

- Election 24 Viz - Experimental: second look for the News Bar, straps, LIVE bug and headline (Graphics style in Branding Control).
- Custom logos (SVG, from a file or searched on Wikimedia Commons, recolourable), Title Control locked while one is set, separate BREAKING accent colour in Branding Control.
- Ticker: RSS providers in a dropdown (read directly over HTTPS), list editor for custom text.
- Live Bug Control: Left / Right / Both.
- Aston Control: one line / in-place BREAKING strap, optional BREAKING headline, text strap ⇄ breaking strap and one line ⇄ two lines without lowering the graphic.
- Title Control (was Tile Control), Testing area, one line Headline Control; Playout Control and Automation are gone.
- Branding Control: News Red Straps sent on connect, window closed at startup, *Send Branding* sends the real *Opaque ticker* value and the *Clock mode*.
- New programme badge presets.
- Bad answers from an RSS server do not crash the helper; the feeds are read directly from the providers over HTTPS (the old `rss.playsamay4.com` server is not used any more).

See the [Viz2.0 readme](https://github.com/BGamerManu/Viz2.0#readme) for screenshots of the graphics themselves.

## License

VizHelper is licensed under the [GNU General Public License v3.0](LICENSE).
