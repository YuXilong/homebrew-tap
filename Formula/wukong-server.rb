# Created by yuxilong on 2026/01/29
class WukongServer < Formula
  desc "WuKong MQTT 消息处理服务"
  homepage "https://github.com/YuXilong/cocoapods-publish"
  version "1.0.8"
  license :cannot_represent

  depends_on arch: :arm64

  url "https://github.com/YuXilong/cocoapods-publish/releases/download/v2.2.0/wukong-server_arm64_#{version}"
  sha256 "7d5570ec6b6469aa0392df63e2322e423757b9a2ac673fd32beb204982184ce4"

  def install
    bin.install "wukong-server_arm64_#{version}" => "wukong-server"
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/wukong-server --version 2>&1", 1)
  end
end
