class AppleLlvmAT21 < Formula
  desc "Apple LLVM from Swift project (official upstream, NOT Hikari)"
  homepage "https://github.com/swiftlang/llvm-project"
  url "https://github.com/swiftlang/llvm-project/archive/refs/tags/swift-6.3-RELEASE.tar.gz"
  sha256 "321c4b5c304533211a324774516f4ea797b03b906725bc27ae447f3aa7924aa4"
  version "21.1.6"
  license "Apache-2.0" => { with: "LLVM-exception" }

  livecheck do
    url "https://github.com/swiftlang/llvm-project/tags"
    regex(/swift[._-]v?(\d+(?:\.\d+)+)[._-]RELEASE/i)
  end

  no_autobump! because: :requires_manual_review

  bottle do
    root_url "https://github.com/YuXilong/homebrew-tap/releases/download/apple-llvm-21.1.6"
    sha256 cellar: :any, arm64_tahoe: "58670d8b9d75ec58dbb4f465e40a078ce33ab33bc9bc1b1add9b35c3ce996b12"
  end

  keg_only :versioned_formula

  depends_on "cmake" => :build
  depends_on "ninja" => :build
  depends_on "python@3.13" => [:build, :test]
  depends_on "xz"
  depends_on "zstd"

  uses_from_macos "libedit"
  uses_from_macos "libffi"
  uses_from_macos "ncurses"
  uses_from_macos "zlib"

  def python3
    "python3.13"
  end

  def clang_config_file_dir
    etc/"clang-apple"
  end

  def install
    # The clang bindings need a little help finding our libclang.
    inreplace "clang/bindings/python/clang/cindex.py",
              /^(\s*library_path\s*=\s*)None$/,
              "\\1'#{lib}'"

    projects = %w[
      llvm
      clang
      clang-tools-extra
    ]

    python_versions = Formula.names
                             .select { |name| name.start_with? "python@" }
                             .map { |py| py.delete_prefix("python@") }

    ENV["SDKROOT"] = MacOS.sdk_for_formula(self).path if OS.mac? && MacOS.sdk_root_needed?
    ENV.libcxx if ENV.compiler == :clang
    ENV.permit_arch_flags

    args = %W[
      -DLLVM_ENABLE_PROJECTS=#{projects.join(";")}
      -DLLVM_TARGETS_TO_BUILD=AArch64
      -DLLVM_INSTALL_UTILS=ON
      -DCMAKE_OSX_ARCHITECTURES=arm64
      -DLLVM_LINK_LLVM_DYLIB=OFF
      -DCLANG_LINK_CLANG_DYLIB=OFF
      -DLLVM_INCLUDE_DOCS=OFF
      -DLLVM_INCLUDE_TESTS=OFF
      -DLLVM_USE_RELATIVE_PATHS_IN_FILES=ON
      -DLLVM_SOURCE_PREFIX=.
      -DCLANG_PYTHON_BINDINGS_VERSIONS=#{python_versions.join(";")}
      -DLLVM_CREATE_XCODE_TOOLCHAIN=OFF
      -DCLANG_FORCE_MATCHING_LIBCLANG_SOVERSION=OFF
      -DCLANG_CONFIG_FILE_SYSTEM_DIR=#{clang_config_file_dir.relative_path_from(bin)}
      -DCLANG_CONFIG_FILE_USER_DIR=~/.config/clang
    ]

    if tap.present?
      args += %W[
        -DPACKAGE_VENDOR=#{tap.user}
        -DBUG_REPORT_URL=#{tap.issues_url}
      ]
    end

    runtimes_cmake_args = []
    builtins_cmake_args = []

    if ENV.cflags.present?
      args << "-DCMAKE_C_FLAGS=#{ENV.cflags}"
      runtimes_cmake_args << "-DCMAKE_C_FLAGS=#{ENV.cflags}"
      builtins_cmake_args << "-DCMAKE_C_FLAGS=#{ENV.cflags}"
    end

    if ENV.cxxflags.present?
      args << "-DCMAKE_CXX_FLAGS=#{ENV.cxxflags}"
      runtimes_cmake_args << "-DCMAKE_CXX_FLAGS=#{ENV.cxxflags}"
      builtins_cmake_args << "-DCMAKE_CXX_FLAGS=#{ENV.cxxflags}"
    end

    args << "-DRUNTIMES_CMAKE_ARGS=#{runtimes_cmake_args.join(";")}" if runtimes_cmake_args.present?
    args << "-DBUILTINS_CMAKE_ARGS=#{builtins_cmake_args.join(";")}" if builtins_cmake_args.present?

    llvmpath = buildpath/"llvm"
    mkdir llvmpath/"build" do
      system "cmake", "-G", "Ninja", "..", *(std_cmake_args + args)
      system "cmake", "--build", "."
      system "cmake", "--build", ".", "--target", "install"
    end

    if OS.mac?
      llvm_version = Utils.safe_popen_read(bin/"llvm-config", "--version").strip
      soversion = Version.new(llvm_version).major.to_s

      lib.install_symlink "libLLVM.dylib" => "libLLVM-#{soversion}.dylib"

      xctoolchain = prefix/"Toolchains/LLVM#{llvm_version}.xctoolchain"

      system "/usr/libexec/PlistBuddy", "-c", "Add:CFBundleIdentifier string org.llvm.#{llvm_version}", "Info.plist"
      system "/usr/libexec/PlistBuddy", "-c", "Add:CompatibilityVersion integer 2", "Info.plist"
      xctoolchain.install "Info.plist"
      (xctoolchain/"usr").install_symlink [bin, include, lib, libexec, share]

      xctoolchain.parent.install_symlink xctoolchain.basename.to_s => "LLVM#{soversion}.xctoolchain"

      MacOSVersion::SYMBOLS.each_value do |v|
        macos_version = MacOSVersion.new(v)
        write_config_files(macos_version, MacOSVersion.kernel_major_version(macos_version), Hardware::CPU.arch)
      end

      write_config_files("", "", Hardware::CPU.arch)
    end

    %w[ftdetect ftplugin indent syntax].each do |dir|
      (share/"vim/vimfiles"/dir).install Pathname.glob("*/utils/vim/#{dir}/*.vim")
    end

    elisp.install llvmpath.glob("utils/emacs/*.el") + share.glob("clang/*.el")
  end

  def write_config_files(macos_version, kernel_version, arch)
    clang_config_file_dir.mkpath

    arches = Set.new([:arm64, :x86_64, :aarch64])
    arches << arch

    sysroot = if macos_version.blank? || (MacOS.version > macos_version && MacOS::CLT.separate_header_package?)
      "#{MacOS::CLT::PKG_PATH}/SDKs/MacOSX.sdk"
    elsif macos_version >= "10.14"
      "#{MacOS::CLT::PKG_PATH}/SDKs/MacOSX#{macos_version}.sdk"
    else
      "/"
    end

    {
      darwin: kernel_version,
      macosx: macos_version,
    }.each do |system, version|
      arches.each do |target_arch|
        config_file = "#{target_arch}-apple-#{system}#{version}.cfg"
        (clang_config_file_dir/config_file).atomic_write <<~CONFIG
          -isysroot #{sysroot}
        CONFIG
      end
    end
  end

  def post_install
    return unless OS.mac?

    config_files = {
      darwin: OS.kernel_version.major,
      macosx: MacOS.version,
    }.map do |system, version|
      clang_config_file_dir/"#{Hardware::CPU.arch}-apple-#{system}#{version}.cfg"
    end
    return if config_files.all?(&:exist?)

    write_config_files(MacOS.version, OS.kernel_version.major, Hardware::CPU.arch)
  end

  def caveats
    <<~EOS
      Apple LLVM #{version} (from Swift project upstream)

      This is the official Apple LLVM, NOT the Hikari obfuscation version.
      For Hikari obfuscation, use the Hikari toolchain instead.

      CLANG_CONFIG_FILE_SYSTEM_DIR: #{clang_config_file_dir}
      CLANG_CONFIG_FILE_USER_DIR:   ~/.config/clang

      Usage:
        #{opt_bin}/clang -v source.c -o output

      LibTooling development:
        # Check headers
        ls #{opt_include}/clang/Tooling/

        # Use llvm-config
        #{opt_bin}/llvm-config --cxxflags --ldflags --libs core

        # CMake integration
        cmake -DCMAKE_PREFIX_PATH=#{opt_prefix} ...
    EOS
  end

  test do
    llvm_version = Utils.safe_popen_read(bin/"llvm-config", "--version").strip
    llvm_version_major = Version.new(llvm_version).major.to_s
    soversion = llvm_version_major.dup
    assert_equal version, llvm_version

    assert_equal prefix.to_s, shell_output("#{bin}/llvm-config --prefix").chomp
    assert_equal "-lLLVM-#{soversion}", shell_output("#{bin}/llvm-config --libs").chomp
    assert_equal (lib/shared_library("libLLVM-#{soversion}")).to_s,
                 shell_output("#{bin}/llvm-config --libfiles").chomp

    (testpath/"test.c").write <<~C
      #include <stdio.h>
      int main()
      {
        printf("Hello World!\\n");
        return 0;
      }
    C

    (testpath/"test.cpp").write <<~CPP
      #include <iostream>
      int main()
      {
        std::cout << "Hello World!" << std::endl;
        return 0;
      }
    CPP

    system bin/"clang-cpp", "-v", "test.c"
    system bin/"clang-cpp", "-v", "test.cpp"

    system bin/"clang++", "-v", "-std=c++11", "test.cpp", "-o", "test++"
    assert_includes MachO::Tools.dylibs("test++"), "/usr/lib/libc++.1.dylib" if OS.mac?
    assert_equal "Hello World!", shell_output("./test++").chomp

    system bin/"clang", "-v", "test.c", "-o", "test"
    assert_equal "Hello World!", shell_output("./test").chomp

    # Verify no Hikari options
    hikari_help = shell_output("#{bin}/clang -mllvm -help 2>&1", 0)
    refute_match(/enable-strcry/, hikari_help)
    refute_match(/enable-bcfobf/, hikari_help)
    refute_match(/enable-cffobf/, hikari_help)

    # Verify LibTooling headers exist
    assert_predicate include/"clang/Tooling/Tooling.h", :exist?
    assert_predicate include/"llvm/ADT/StringRef.h", :exist?

    # Verify CMake config exists
    assert_predicate lib/"cmake/clang/ClangConfig.cmake", :exist?
    assert_predicate lib/"cmake/llvm/LLVMConfig.cmake", :exist?

    # Test clang-format
    (testpath/"clangformattest.c").write <<~C
      int    main() {
          printf("Hello world!"); }
    C
    assert_equal "int main() { printf(\"Hello world!\"); }\n",
      shell_output("#{bin}/clang-format -style=google clangformattest.c")
  end
end
