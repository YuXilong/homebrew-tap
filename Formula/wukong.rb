# Created by yuxilong on 2026/01/29
class Wukong < Formula
  desc "iOS 工程自动化工具集"
  homepage "https://github.com/YuXilong/cocoapods-publish"
  url "https://github.com/YuXilong/cocoapods-publish/releases/download/v2.2.0/wukong_arm64_3.0.28"
  version "3.0.28"
  sha256 "5101044ad8774b53fe49eb6f014b9cf6b0c05ea2890360b01a6fe1ba092d4cba"
  license :cannot_represent

  depends_on :macos
  depends_on "ruby@3.3"

  on_intel do
    on_macos do
      url "https://github.com/YuXilong/cocoapods-publish/releases/download/v2.2.0/wukong_x86_64_3.0.28"
      sha256 "9adbd1e65d97db67071372c1c3965909763872ef86be731c44d495c73f87cd0b"
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
    state_dir = var/"wukong"
    initialized_stamp = state_dir/"environment-initialized"
    if initialized_stamp.exist?
      ohai "WuKong 环境已初始化，跳过 CocoaPods 与插件安装"
      return
    end

    ruby_bin = formula_opt_bin("ruby@3.3")
    gem_home = HOMEBREW_PREFIX/"lib/ruby/gems/3.3.0"
    gem_bin = gem_home/"bin"

    ENV["GEM_HOME"] = gem_home.to_s
    ENV["GEM_SPEC_CACHE"] = "#{gem_home}/specs"
    ENV.prepend_path "PATH", gem_bin.to_s
    ENV.prepend_path "PATH", ruby_bin.to_s

    gem_cmd = ruby_bin/"gem"
    installed_gems = `#{gem_cmd} list --local 2>/dev/null`
    required_gems = %w[cocoapods cocoapods-publish cocoapods-packager]
    if required_gems.all? { |gem_name| installed_gems.match?(/^#{Regexp.escape(gem_name)}\s/) }
      state_dir.mkpath
      initialized_stamp.write("existing environment\n")
      ohai "检测到已有 CocoaPods 环境，已标记为初始化完成"
      return
    end

    cocoapods_version = "1.15.2"
    unless installed_gems.match?(/^cocoapods\s.*\b#{Regexp.escape(cocoapods_version)}\b/)
      ohai "正在安装 CocoaPods #{cocoapods_version}..."
      unless system gem_cmd, "install", "cocoapods", "-v", cocoapods_version, "--no-document"
        opoo "CocoaPods 安装失败，可稍后执行 brew postinstall wukong 重试"
        return
      end
    end

    require "json"
    require "tmpdir"
    tmpdir = Pathname.new(Dir.mktmpdir("wukong_gems"))
    plugins_installed = true

    begin
      ohai "正在从 GitHub 资产桶获取 CocoaPods 插件信息..."
      api_json_file = tmpdir/"release.json"
      unless system "curl", "-fsSL",
                    "-H", "Accept: application/vnd.github+json",
                    "-o", api_json_file.to_s,
                    "https://api.github.com/repos/YuXilong/cocoapods-publish/releases/tags/v2.2.0"
        raise "获取 CocoaPods 插件信息失败"
      end

      assets = JSON.parse(api_json_file.read)["assets"] || []
      %w[cocoapods-publish cocoapods-packager].each do |gem_name|
        asset = assets.find do |candidate|
          candidate["name"].start_with?("#{gem_name}-") && candidate["name"].end_with?(".gem")
        end
        raise "未找到 #{gem_name} 安装包" unless asset

        remote_version = asset["name"].match(/#{Regexp.escape(gem_name)}-(.+)\.gem/)[1]
        next if installed_gems.match?(/^#{Regexp.escape(gem_name)}\s.*\b#{Regexp.escape(remote_version)}\b/)

        ohai "正在安装 #{asset["name"]}..."
        gem_file = tmpdir/asset["name"]
        unless system "curl", "-fsSL", "-o", gem_file.to_s, asset["browser_download_url"]
          raise "下载 #{asset["name"]} 失败"
        end
        unless system gem_cmd, "install", gem_file.to_s, "--no-document"
          raise "安装 #{asset["name"]} 失败"
        end
      end
    rescue => e
      plugins_installed = false
      opoo "CocoaPods 插件安装失败: #{e.message}（可稍后执行 brew postinstall wukong 重试）"
    ensure
      rm_r tmpdir if tmpdir.exist?
    end

    return unless plugins_installed

    state_dir.mkpath
    initialized_stamp.write("#{version}\n")
    ohai "WuKong 环境初始化完成"
  end

  def caveats
    ruby_bin = formula_opt_bin("ruby@3.3")
    gem_bin = HOMEBREW_PREFIX/"lib/ruby/gems/3.3.0/bin"
    brew_wukong = HOMEBREW_PREFIX/"bin/wukong"

    <<~EOS
      wukong 已安装完成。CocoaPods 与插件只在首次安装时初始化。

      请将以下内容添加到 ~/.zshrc（如尚未添加）：
        export PATH="#{ruby_bin}:#{gem_bin}:$PATH"

      如果旧版 ~/.local/bin/wukong 仍优先于 Homebrew，请执行：
        "#{brew_wukong}" update

      主动更新 CocoaPods 插件：
        wukong update --pod-plugins

      安装 iOS Git Hooks（可选）：
        curl -fsSL https://raw.githubusercontent.com/BaiTu-iOS/ios-git-hooks/main/install.sh | sh

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
