# Created by yuxilong on 2026/01/29
class WukongServer < Formula
  desc "WuKong MQTT 消息处理服务"
  homepage "https://github.com/YuXilong/cocoapods-publish"
  url "https://github.com/YuXilong/cocoapods-publish/releases/download/v2.2.0/wukong-server_arm64_1.0.15"
  sha256 "7fbf8bd24dcc14be26fc24bc79ff48f0039674bc3d138121a832fe9f91fd7bb8"
  license :cannot_represent

  depends_on arch: :arm64
  depends_on :macos

  def install
    bin.install "wukong-server_arm64_#{version}" => "wukong-server"
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/wukong-server --version 2>&1", 1)
  end
end
