class SwiftDump < Formula
  desc "Recover Swift type declarations from Mach-O files"
  homepage "https://github.com/YuXilong/SwiftDump"
  url "https://github.com/YuXilong/SwiftDump/releases/download/v1.2.0/SwiftDump-v1.2.0-macos-universal.zip"
  sha256 "4dd85e846aa20b801ace3a5385460a3b1c9440eeb35cd63e425c96d310383d03"
  license "MIT"

  depends_on :macos

  def install
    bin.install "SwiftDump"
    bin.install_symlink bin/"SwiftDump" => "swift-dump"
  end

  test do
    assert_match "SwiftDump v#{version}", shell_output("#{bin}/SwiftDump --version")
    assert_match "SwiftDump v#{version}", shell_output("#{bin}/swift-dump --version")
  end
end
