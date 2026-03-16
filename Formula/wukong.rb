# Created by yuxilong on 2026/01/29
class Wukong < Formula
  desc "iOS 工程自动化工具集"
  homepage "https://github.com/YuXilong/cocoapods-publish"
  version "3.0.9"
  license :cannot_represent

  no_autobump! because: :requires_manual_review

  depends_on "ruby@3.3"

  on_macos do
    if Hardware::CPU.arm?
      url "https://github.com/YuXilong/cocoapods-publish/releases/download/v2.2.0/wukong_arm64_#{version}"
      sha256 "3bc3ed2e3fc6244c80dfc71825ae371b0fc9a8f14affa22edf0277af48ab3f36"
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

  def post_install
    # 配置 gem 使用国内镜像源并安装 CocoaPods 1.15.2
    ruby_bin = Formula["ruby@3.3"].opt_bin
    gem_cmd = ruby_bin/"gem"

    system gem_cmd, "sources", "--remove", "https://rubygems.org/"
    system gem_cmd, "sources", "--add", "https://gems.ruby-china.com/"
    system gem_cmd, "install", "cocoapods", "-v", "1.15.2"

    # 更新 wukong 自身配置与 CocoaPods 插件
    system bin/"wukong", "update"
    system bin/"wukong", "update", "--pod-plugins"

    # 添加私有 CocoaPods 仓库（需要 GIT_LAB_HOST 环境变量）
    git_lab_host = ENV["GIT_LAB_HOST"]
    if git_lab_host && !git_lab_host.empty?
      repos_dir = File.expand_path("~/.cocoapods/repos/BaiTuFrameworkPods")
      unless Dir.exist?(repos_dir)
        system "pod", "repo", "add", "BaiTuFrameworkPods",
               "https://#{git_lab_host}/ios_framework/frameworkpods.git"
      end
      system "pod", "repo", "update", "BaiTuFrameworkPods"
    else
      opoo "GIT_LAB_HOST 未设置，跳过 BaiTuFrameworkPods 仓库配置。\n" \
           "安装后请手动执行：\n" \
           "  pod repo add BaiTuFrameworkPods https://<YOUR_GITLAB_HOST>/ios_framework/frameworkpods.git"
    end
  end

  def caveats
    <<~EOS
      wukong 已安装完成。

      CocoaPods 1.15.2 已通过 gem 安装（使用 ruby-china 镜像源）。
      请确保 Ruby 3.3 的 gem bin 目录在 PATH 中：
        echo 'export PATH="#{Formula["ruby@3.3"].opt_bin}:$PATH"' >> ~/.zshrc

      如果你尚未设置 GIT_LAB_HOST 环境变量，请手动添加私有仓库：
        export GIT_LAB_HOST=your-gitlab-host
        pod repo add BaiTuFrameworkPods https://$GIT_LAB_HOST/ios_framework/frameworkpods.git
        pod repo update BaiTuFrameworkPods
    EOS
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/wukong --version")
  end
end
