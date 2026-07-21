class SwiftDump < Formula
  desc "Recover Swift type declarations from Mach-O files"
  homepage "https://github.com/YuXilong/SwiftDump"
  url "https://github.com/YuXilong/SwiftDump/releases/download/v1.2.2/SwiftDump-v1.2.2-macos-universal.zip"
  sha256 "447e141cb2bcd3d36e5700babbf26a6f9cfb4d4db693c6edfc4d7fb172a0f152"
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
