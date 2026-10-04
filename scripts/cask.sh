#!/bin/bash
# Prints the Homebrew cask for a release: scripts/cask.sh <version> <zip>
# The release workflow commits it to github.com/marcneuwirth/homebrew-tap as Casks/mullion.rb.
set -euo pipefail

VERSION="$1"
SHA256="$(shasum -a 256 "$2" | cut -d' ' -f1)"

cat <<CASK
cask "mullion" do
  version "$VERSION"
  sha256 "$SHA256"

  url "https://github.com/marcneuwirth/mullion/releases/download/v#{version}/Mullion-#{version}.zip"
  name "Mullion"
  desc "Keyboard-only grid window manager"
  homepage "https://github.com/marcneuwirth/mullion"

  depends_on macos: :ventura

  app "Mullion.app"
  binary "#{appdir}/Mullion.app/Contents/MacOS/Mullion", target: "mullion"

  # Start it now rather than at the next login: the first launch writes the default config and adds
  # Mullion to Login Items. On upgrade, this restarts the new version after the uninstall quit stopped the old one.
  postflight do
    system_command "/usr/bin/open", args: ["#{appdir}/Mullion.app"]
  end

  uninstall early_script: {
              executable:   "#{appdir}/Mullion.app/Contents/MacOS/Mullion",
              args:         ["--unregister"],
              must_succeed: false,
            },
            quit:         "com.marcneuwirth.mullion"

  zap trash: [
    "~/.config/mullion",
    "~/Library/Logs/Mullion.log",
    "~/Library/Preferences/com.marcneuwirth.mullion.plist",
  ]
end
CASK
