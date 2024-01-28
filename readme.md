<div align="center">
	<a href="https://sindresorhus.com/system-color-picker">
		<img src="Stuff/AppIcon-readme.png" width="200" height="200">
	</a>
	<h1>System Color Picker</h1>
	<p>
		<b>The familiar color picker supercharged</b>
	</p>
	<br>
	<br>
	<br>
</div>

The macOS color picker as an app with lots of extra features.

## Download

[![](https://tools.applemediaservices.com/api/badges/download-on-the-mac-app-store/black/en-us?size=250x83&releaseDate=1615852800)](https://apps.apple.com/app/id1545870783)

Requires macOS 14 or later.

**Older versions**

- [1.15.0](https://github.com/sindresorhus/System-Color-Picker/releases/download/v1.15.0/Color.Picker.1.15.0.-.macOS.13.zip) for macOS 13+
- [1.12.1](https://github.com/sindresorhus/System-Color-Picker/releases/download/v1.12.1/Color.Picker.1.12.1.-.macOS.12.zip) for macOS 12+
- [1.9.6](https://github.com/sindresorhus/System-Color-Picker/releases/download/v1.9.6/Color.Picker.1.9.6.-.macOS.11.zip) for macOS 11+

**Non-App Store version**

A special version for users that cannot access the App Store. It won't receive automatic updates. I will update it here once a year.

[Download](https://www.dropbox.com/scl/fi/v5g3wgxwipx7x05dkc4oh/Color-Picker-2.0.0-1706349638.zip?rlkey=zk983dubrc2t0gh9pc2bimoaa&raw=1) *(2.0.0 · macOS 14+)*

## Features

- Palettes
- Recently picked colors
- Quickly copy, paste, and convert colors in Hex, HSL, RGB, LCH format
- Show as a normal app or in the menu bar
- Pick a color or toggle the window from anywhere with a global keyboard shortcut
- Make the window stay on top of all other windows
- Launch it at login (when in the menu bar)
- Hide menu bar icon
- Shortcuts support

## Tips

- Press the <kbd>Space</kbd> key while using the color sampler to show the RGB values. The color sampler is a system component and it can unfortunately not show other kinds of color values.
- Press the <kbd>Option</kbd> key when copying the Hex color to invert whether to include `#`.
- Press the <kbd>Shift</kbd> key while selecting a color using the color sampler to prevent it from disappearing after your selection.

## Keyboard shortcuts

You can use the following keyboard shortcuts in the app:

- Pick color: <kbd>Command</kbd> <kbd>p</kbd>
- Copy as Hex: <kbd>Shift</kbd> <kbd>Command</kbd> <kbd>h</kbd>
- Copy as HSL: <kbd>Shift</kbd> <kbd>Command</kbd> <kbd>s</kbd>
- Copy as RGB: <kbd>Shift</kbd> <kbd>Command</kbd> <kbd>r</kbd>
- Copy as OKLCH: <kbd>Shift</kbd> <kbd>Command</kbd> <kbd>o</kbd>
- Copy as LCH: <kbd>Shift</kbd> <kbd>Command</kbd> <kbd>l</kbd>
- Paste color: <kbd>Shift</kbd> <kbd>Command</kbd> <kbd>v</kbd> *(In the format Hex, HSL, RGB, or LCH)*
- Reset opacity: <kbd>Control</kbd> <kbd>Shift</kbd> <kbd>o</kbd>

## Plugins

The built-in color picker supports plugins:

- [Scala Color](https://bjango.com/mac/skalacolor/)
- [Pro Picker](https://formulae.brew.sh/cask/colorpicker-propicker)
- [Material Design](https://github.com/johnyanarella/MaterialDesignColorPicker)
- [Color Picker Plus](https://github.com/viktorstrate/color-picker-plus)

## Screenshots

![](Stuff/screenshot1.jpg)
![](Stuff/screenshot2.jpg)

## FAQ

#### The app does not show up in the menu bar

macOS hides menu bar apps when there is no space left in the menu bar. This is a common problem on MacBooks with a notch. Try quitting some menu bar apps to free up space. If this does not solve it, try quitting Bartender if you have it installed.

#### What is OKLCH color?

[It's a more human-friendly color format.](https://evilmartians.com/chronicles/oklch-in-css-why-quit-rgb-hsl) Prefer this format.

#### How is OKLCH better than LCH?

[OKLCH](https://evilmartians.com/chronicles/oklch-in-css-why-quit-rgb-hsl) improves upon [LCH](https://lea.verou.me/2020/04/lch-colors-in-css-what-why-and-how/) by providing more accurate and consistent colors, particularly in very bright or very saturated areas.

#### The color changes if I copy and then paste it

That is because the default color space in the picker is [Display P3](https://en.wikipedia.org/wiki/DCI-P3), which is [part of CSS Color 4](https://drafts.csswg.org/css-color-4/#valdef-color-display-p3), but the color space used for the legacy CSS color formats is [sRGB](https://en.wikipedia.org/wiki/SRGB) (browsers are starting to [handle color spaces](https://css-tricks.com/the-expanding-gamut-of-color-on-the-web/) but they are not all there yet).

#### How do I use palettes?

You can manage palettes by selecting the third tab in the window toolbar.

The fastest way to add a color to a palette is to paste a Hex color value into the app and then click the `+` button in the palette. You can also drag and drop a color into the palette from anywhere.

Palettes can be accessed both from the app and the menu bar icon (if enabled). You can even access them in other apps that use the system color picker.

You can find palettes on [Coolors](https://coolors.co/palettes/trending).

#### How do I change the color space?

Right-click the color wheel. You want to select “Display P3” if you use LCH or “sRGB” if you use Hex, HSL, or RGB.

Note that the HSL and RGB format will always be clamped to [sRGB](https://en.wikipedia.org/wiki/SRGB) color space.

#### Can you support `SwiftUI.Color` / `UIColor` / `NSColor` formats?

The best practice is to use [Asset Catalog for colors](https://devblog.xero.com/managing-ui-colours-with-ios-11-asset-catalogs-16500ba48205) instead of hard-coding the values in code. If you really want to hard-code colors, the [Scala color picker plugin](https://bjango.com/mac/skalacolor/) supports `UIColor` and `NSColor`.

#### Can I contribute localizations?

I don't plan to localize the app.

#### [More FAQs…](https://sindresorhus.com/apps/faq)

## Built with

- [Defaults](https://github.com/sindresorhus/Defaults) - Swifty and modern UserDefaults
- [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) - Add user-customizable global keyboard shortcuts to your macOS app
- [LaunchAtLogin](https://github.com/sindresorhus/LaunchAtLogin) - Add “Launch at Login” functionality to your macOS app

## Other apps

- [Gifski](https://github.com/sindresorhus/Gifski) - Convert videos to high-quality GIFs
- [Plash](https://github.com/sindresorhus/Plash) - Make any website your Mac desktop wallpaper
- [More apps…](https://sindresorhus.com/apps)
