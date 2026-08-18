cask "ticker" do
  version "1.0.4"
  sha256 "6f4809c034c90037e4552d031acc99696658ec64f88cdad37905e92d640cb095"

  url "https://github.com/ajaysuwalka/ticker-app/releases/download/v#{version}/Ticker-#{version}.dmg",
      verified: "github.com/ajaysuwalka/ticker-app/"
  name "Ticker"
  desc "Private, native macOS time tracker with focus & wellness breaks"
  homepage "https://github.com/ajaysuwalka/ticker-app"

  depends_on macos: :sonoma # macOS 14+ (minimum)

  app "Ticker.app"

  # `brew uninstall --zap` also removes tracked data.
  zap trash: [
    "~/Library/Application Support/Ticker",
  ]
end
