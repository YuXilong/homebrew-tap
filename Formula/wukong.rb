# Created by yuxilong on 2026/01/29
class Wukong < Formula
  desc "iOS 工程自动化工具集"
  homepage "https://github.com/YuXilong/cocoapods-publish"
  version "3.0.6"
  license :cannot_represent

  no_autobump! because: :requires_manual_review

  on_macos do
    if Hardware::CPU.arm?
      url "https://github.com/YuXilong/cocoapods-publish/releases/download/v2.2.0/wukong_arm64_#{version}"
      sha256 "5baefc75ec4e701d6e0e3327b0303485bb39bba3178e1e3ad49aa7b9b3f40436"
    elsif Hardware::CPU.intel?
      url "https://github.com/YuXilong/cocoapods-publish/releases/download/v2.2.0/wukong_x86_64_#{version}"
      sha256 "f7bbb239fcade7ea9f1c7b9edeb300dec26dbf5875e0249a4761eab4a94d37a1"
    end
  end

  def install
    if Hardware::CPU.arm?
      bin.install "wukong_arm64_#{version}" => "wukong"
    elsif Hardware::CPU.intel?
      bin.install "wukong_x86_64_#{version}" => "wukong"
    end
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/wukong --version")
  end
end
