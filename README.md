# Yuxilong Tap

自用 Homebrew Tap，提供 iOS/macOS 开发相关工具。

## 可用 Formula

| Formula | 版本 | 说明 | 架构 |
|---------|------|------|------|
| `wukong` | 3.0.9 | iOS 工程自动化工具集 | arm64 / x86_64 |
| `wukong-server` | 1.0.4 | WuKong MQTT 消息处理服务 | arm64 |
| `apple-llvm@19` | 19.1.5 | Apple LLVM（Swift 项目官方上游） | arm64 |
| `llvm@19` | 19.1.5 | LLVM 编译器基础设施（含 Hikari 混淆支持） | arm64 |

## 安装方式

```bash
brew install yuxilong/tap/<formula>
```

或者先添加 tap 再安装：

```bash
brew tap yuxilong/tap
brew install <formula>
```

也可以在 `Brewfile` 中使用：

```ruby
tap "yuxilong/tap"
brew "wukong"
```

## 文档

`brew help`、`man brew` 或查看 [Homebrew 官方文档](https://docs.brew.sh)。
