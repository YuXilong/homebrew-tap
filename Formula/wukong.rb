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
    # 若 ~/.local/bin/wukong 存在（旧版安装位置），替换为指向 Homebrew 版本的符号链接
    old_wukong = "#{Dir.home}/.local/bin/wukong"
    brew_wukong = "#{HOMEBREW_PREFIX}/bin/wukong"
    needs_link = false
    if File.exist?(old_wukong) && !File.symlink?(old_wukong)
      needs_link = true
    elsif File.symlink?(old_wukong) && File.readlink(old_wukong) != brew_wukong
      needs_link = true
    end

    if needs_link
      if Kernel.system("rm", "-f", old_wukong) && Kernel.system("ln", "-sf", brew_wukong, old_wukong)
        ohai "已将 #{old_wukong} 替换为 -> #{brew_wukong} 的符号链接"
      else
        opoo "无法自动替换 #{old_wukong}（sandbox 限制），请手动执行：\n  rm -f #{old_wukong} && ln -sf #{brew_wukong} #{old_wukong}"
      end
    end

    ruby_bin = Formula["ruby@3.3"].opt_bin
    gem_home = HOMEBREW_PREFIX/"lib/ruby/gems/3.3.0"
    gem_bin  = gem_home/"bin"

    # 在 sandbox 中必须将 gem 写入 HOMEBREW_PREFIX 可写目录
    ENV["GEM_HOME"] = gem_home.to_s
    ENV["GEM_SPEC_CACHE"] = "#{gem_home}/specs"
    ENV.prepend_path "PATH", gem_bin.to_s
    ENV.prepend_path "PATH", ruby_bin.to_s

    gem_cmd = ruby_bin/"gem"

    # 检查 gem 是否已安装指定版本
    installed_gems = `#{gem_cmd} list --local 2>/dev/null`

    # 安装 CocoaPods 1.15.2
    cocoapods_version = "1.15.2"
    if installed_gems.match?(/^cocoapods\s.*\b#{Regexp.escape(cocoapods_version)}\b/)
      ohai "CocoaPods #{cocoapods_version} 已安装，跳过"
    else
      ohai "正在安装 CocoaPods #{cocoapods_version}..."
      system gem_cmd, "install", "cocoapods", "-v", cocoapods_version, "--no-document"
    end

    # 从 GitHub 最新 release 下载并安装 cocoapods-publish 和 cocoapods-packager
    require "tmpdir"
    tmpdir = Pathname.new(Dir.mktmpdir("wukong_gems"))

    begin
      ohai "正在从 GitHub 获取最新 CocoaPods 插件信息..."
      api_json_file = tmpdir/"release.json"
      system "curl", "-fsSL",
             "-H", "Accept: application/vnd.github+json",
             "-o", api_json_file.to_s,
             "https://api.github.com/repos/YuXilong/cocoapods-publish/releases/latest"

      require "json"
      assets = JSON.parse(api_json_file.read)["assets"] || []

      %w[cocoapods-publish cocoapods-packager].each do |gem_name|
        asset = assets.find { |a| a["name"].start_with?("#{gem_name}-") && a["name"].end_with?(".gem") }
        next unless asset

        # 从文件名提取版本号，如 cocoapods-publish-2.7.7.gem -> 2.7.7
        remote_version = asset["name"].match(/#{Regexp.escape(gem_name)}-(.+)\.gem/)[1]

        if installed_gems.match?(/^#{Regexp.escape(gem_name)}\s.*\b#{Regexp.escape(remote_version)}\b/)
          ohai "#{gem_name} #{remote_version} 已安装，跳过"
          next
        end

        ohai "正在安装 #{asset["name"]}..."
        gem_file = tmpdir/asset["name"]
        system "curl", "-fsSL", "-o", gem_file.to_s, asset["browser_download_url"]
        system gem_cmd, "install", gem_file.to_s, "--no-document"
        ohai "已安装 #{asset["name"]}"
      end

      # 安装 iOS Git Hooks（sandbox 外才能执行 git clone，故放入 caveats 提示）
    rescue => e
      opoo "CocoaPods 插件安装失败: #{e.message}（可稍后手动安装）"
    ensure
      tmpdir.rmtree if tmpdir.exist?
    end
  end

  def caveats
    ruby_bin = Formula["ruby@3.3"].opt_bin
    gem_bin  = HOMEBREW_PREFIX/"lib/ruby/gems/3.3.0/bin"

    old_wukong = "#{Dir.home}/.local/bin/wukong"
    brew_wukong = "#{HOMEBREW_PREFIX}/bin/wukong"
    link_hint = ""
    if File.exist?(old_wukong) && !File.symlink?(old_wukong)
      link_hint = <<~HINT

        检测到旧版 wukong，请手动替换为符号链接：
          rm -f #{old_wukong} && ln -sf #{brew_wukong} #{old_wukong}
      HINT
    end

    <<~EOS
      wukong 已安装完成。以下组件已自动安装：
        • CocoaPods 1.15.2
        • cocoapods-publish / cocoapods-packager（从 GitHub 最新 release）
      #{link_hint}
      请将以下内容添加到 ~/.zshrc（如尚未添加）：
        export PATH="#{ruby_bin}:#{gem_bin}:$PATH"

      然后执行以下命令完成初始化：
        source ~/.zshrc
        wukong update

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
