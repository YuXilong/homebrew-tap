# Created by yuxilong on 2026/01/29
class Wukong < Formula
  desc "iOS 工程自动化工具集"
  homepage "https://github.com/YuXilong/cocoapods-publish"
  version "3.0.11"
  license :cannot_represent

  no_autobump! because: "uses custom versioned release URLs"

  depends_on "ruby@3.3"

  on_macos do
    if Hardware::CPU.arm?
      url "https://github.com/YuXilong/cocoapods-publish/releases/download/v2.2.0/wukong_arm64_#{version}"
      sha256 "96df8b9c0aa2158c9a8bf4f1250683d192d5d65e223e34707991837af19199f1"
    elsif Hardware::CPU.intel?
      url "https://github.com/YuXilong/cocoapods-publish/releases/download/v2.2.0/wukong_x86_64_#{version}"
      sha256 "91a12e57dff44b4ea8b2e9afdd6293204e4ffe64037d525657947a54009b1909"
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
    ruby_bin = Formula["ruby@3.3"].opt_bin
    gem_home = HOMEBREW_PREFIX/"lib/ruby/gems/3.3.0"
    gem_bin  = gem_home/"bin"

    # 在 sandbox 中必须将 gem 写入 HOMEBREW_PREFIX 可写目录
    ENV["GEM_HOME"] = gem_home.to_s
    ENV["GEM_SPEC_CACHE"] = "#{gem_home}/specs"
    ENV.prepend_path "PATH", gem_bin.to_s
    ENV.prepend_path "PATH", ruby_bin.to_s

    gem_cmd = ruby_bin/"gem"

    # 安装 CocoaPods 1.15.2（使用默认 rubygems.org 源）
    system gem_cmd, "install", "cocoapods", "-v", "1.15.2", "--no-document"
  end

  def caveats
    ruby_bin = Formula["ruby@3.3"].opt_bin
    gem_bin  = HOMEBREW_PREFIX/"lib/ruby/gems/3.3.0/bin"
    <<~EOS
      wukong 已安装完成，CocoaPods 1.15.2 已自动安装。

      请将以下内容添加到 ~/.zshrc（如尚未添加）：
        export PATH="#{ruby_bin}:#{gem_bin}:$PATH"

      然后执行以下命令完成初始化：
        source ~/.zshrc
        wukong update
        wukong update --pod-plugins

      如需配置私有仓库：
        export GIT_LAB_HOST=your-gitlab-host
        pod repo add BaiTuFrameworkPods https://$GIT_LAB_HOST/ios_framework/frameworkpods.git
        pod repo update BaiTuFrameworkPods
    EOS
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/wukong --version")
  end
end
