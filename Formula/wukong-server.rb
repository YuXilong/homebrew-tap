# Created by yuxilong on 2026/01/29
class WukongServer < Formula
  desc "WuKong MQTT 消息处理服务"
  homepage "https://github.com/YuXilong/cocoapods-publish"
  version "1.0.4"
  license :cannot_represent

  no_autobump! because: :requires_manual_review

  depends_on arch: :arm64

  url "https://github.com/YuXilong/cocoapods-publish/releases/download/v2.2.0/wukong-server_arm64_#{version}"
  sha256 "4421938f8836e5f49bc1a94b5b35b2592cac88641150a5ad36d7884dbebc1787"

  def install
    bin.install "wukong-server_arm64_#{version}" => "wukong-server"
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/wukong-server --version 2>&1", 1)
  end
end
