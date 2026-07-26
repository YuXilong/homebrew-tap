class SwiftDump < Formula
  desc "Recover Swift type declarations from Mach-O files"
  homepage "https://github.com/YuXilong/SwiftDump"
  url "https://github.com/YuXilong/SwiftDump/releases/download/v1.2.3/SwiftDump-v1.2.3-macos-universal.zip"
  sha256 "b8d7a149a6d90a4b6bda006b00f92c8d615043662a4fdc6acfbf8deb81338f9b"
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
