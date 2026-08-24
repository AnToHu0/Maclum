# Maclum

Maclum is a macOS menu-bar app that keeps external DDC/CI monitors in step with
the brightness of a MacBook’s built-in display. It follows both automatic and
manual brightness changes on the Mac.

Each monitor has its own `Low / Mid / High` curve, so the same Mac brightness
can produce different luminance on different displays. Moving a curve handle
previews that exact value on the corresponding monitor immediately.

## Requirements

- macOS 15 or later
- An Apple-Silicon MacBook with a built-in display
- An external monitor with DDC/CI enabled
- [m1ddc](https://github.com/waydabber/m1ddc), installed through Homebrew:

  ```zsh
  brew install m1ddc
  ```

Maclum does not install Homebrew or m1ddc automatically. If m1ddc is missing,
the app offers the same command for copying into Terminal.

## Use

Open Maclum from the menu bar. The header shows the current Mac brightness;
each compatible monitor gets a card with its reported brightness and curve.

- `Low`, `Mid`, and `High` correspond to 0%, 50%, and 100% Mac brightness.
- Curve points stay ordered and cannot cross.
- All compatible connected monitors synchronize at the same time, each with its
  own saved curve.
- Turn off the monitor's own automatic-brightness feature; it can override DDC
  brightness commands.
- A monitor that does not answer the DDC brightness probe is not shown or
  controlled. Maclum checks it again when you refresh the display list.
- Profiles for previously connected monitors are retained. Use **Show
  disconnected displays** to review or delete them.

Settings are stored locally at
`~/Library/Application Support/Maclum/settings.json`.

## Download

Download `Maclum-macos-apple-silicon.zip` and its `.sha256` file from
[GitHub Releases](../../releases). Verify the download before opening it:

```zsh
shasum -a 256 -c Maclum-macos-apple-silicon.zip.sha256
```

Move `Maclum.app` to Applications. Releases are ad-hoc builds, so macOS may
require **Open** from the context menu on first launch.

## Build and run

Building requires full Xcode.

```zsh
./scripts/test.sh
./scripts/build-app.sh
./scripts/verify-app-bundle.sh
open .build/app/Maclum.app
```
## Limitations

Maclum reads built-in-display brightness through Apple’s private
`DisplayServices` framework. It is intended for local and open-source use, not
the Mac App Store; notarization may also be unavailable.

## License

MIT. See [LICENSE](LICENSE).
