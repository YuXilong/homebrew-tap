# Created by yuxilong on 2026/01/29
class WukongServer < Formula
  desc "WuKong MQTT 消息处理服务"
  homepage "https://github.com/YuXilong/cocoapods-publish"
  version "1.0.10"
  license :cannot_represent

  depends_on arch: :arm64

  url "https://github.com/YuXilong/cocoapods-publish/releases/download/v2.2.0/wukong-server_arm64_#{version}"
  sha256 "8944deb1daba7d6c07758e5f5f926dca983b2913e5d9b08cc90aaa88f358ab7e"

  def install
    bin.install "wukong-server_arm64_#{version}" => "wukong-server"
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/wukong-server --version 2>&1", 1)
  end
end
