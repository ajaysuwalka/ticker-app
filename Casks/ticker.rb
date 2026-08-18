cask "ticker" do
  version "1.0.2"
  sha256 "994e8ff6ac12441879af4d0d3438ee1ffd47471ad5686e3be0b0db73fe49893b"

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
