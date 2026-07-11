cask "gitpanel" do
  version "1.0.0"
  sha256 "PLACEHOLDER_SHA256"

  url "https://github.com/vaib2607/GitPanel-Live-Git-Status-in-Menu-Bar-for-Claude-Code/releases/download/v#{version}/GitPanel.dmg"
  name "GitPanel"
  desc "Live git status in your menu bar for Claude Code"
  homepage "https://github.com/vaib2607/GitPanel-Live-Git-Status-in-Menu-Bar-for-Claude-Code"

  depends_on macos: ">= :sonoma"

  app "GitPanel.app"

  zap trash: [
    "~/Library/Preferences/com.gitpanel.app.plist",
    "~/Library/Application Support/GitPanel",
  ]
end
