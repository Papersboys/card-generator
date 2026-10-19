# Link Card

[English](README.md) | [简体中文](README.zh-CN.md)

<img src="Assets/AppIcon.png" alt="Link Card 应用图标" width="128" />

原生 macOS 菜单栏 App，用于创建 Link 付款请求、在 Link 中批准请求、查看虚拟卡信息，以及取消未使用的请求。使用 SwiftUI、AppKit 和 URLSession 构建。

运行 `./build.sh` 后打开 `dist/LinkCard.app`。通过菜单栏信用卡图标打开窗口或退出；也可以将 App 安装到 Applications 文件夹。

**无需安装 link-cli、Node.js、npm、Shell helper 或本地服务。** 需要 Apple Silicon 和 macOS 13 或更新版本。

## 文档

| 文档 | 简体中文 | English |
| --- | --- | --- |
| 安装指南 | [系统要求、安装、构建与更新](docs/INSTALL.zh-CN.md) | [Installation guide](docs/INSTALL.en.md) |
| 使用说明 | [带截图的完整使用流程](docs/USAGE.zh-CN.md) | [Illustrated usage guide](docs/USAGE.en.md) |

## 界面展示

| 请求与历史 · 中文 | 创建请求 · English |
| --- | --- |
| ![显示示例登录账户的中文历史列表](docs/images/overview-zh.jpg) | ![使用虚构购买信息的英文创建表单](docs/images/create-en.jpg) |

截图使用虚构示例数据。使用说明还包含登录、卡详情和创建／取消确认框截图。

## 安装

已打包的 App 无需 Xcode 或 CLI。源码构建需要 Xcode 和 macOS SDK。仓库不包含打包二进制；请使用可信来源的 App 包，或自行构建。

### 从源码快速开始

安装并配置 Xcode，然后运行：

```bash
git clone https://github.com/Papersboys/card-generator.git
cd card-generator
./build.sh
open dist/LinkCard.app
```

运行离线测试：

```bash
./test.sh
```

构建产物不会纳入 Git。退出正在运行的 App，再安装到个人 Applications 文件夹：

```bash
mkdir -p "$HOME/Applications"
ditto dist/LinkCard.app "$HOME/Applications/LinkCard.app"
open "$HOME/Applications/LinkCard.app"
```

更新时先退出 App，保存本地源码修改，再执行 `git pull --ff-only` 和 `./build.sh`，最后替换安装的 App。当前没有自动更新功能，也不会自动设置开机启动。构建使用本地 ad-hoc 签名，未经过 Apple 公证。详细步骤见[安装指南](docs/INSTALL.zh-CN.md)。

## 语言

使用窗口顶部 **中文 / English** 切换控件。界面、菜单栏菜单、确认框、卡信息字段、状态和 App 自身提示会即时更新，重启后保留选择。商家名称、用途、请求 ID 和卡信息本身不会被翻译。

## 登录

登录成功后，按钮会替换为 **已登录** 及 Link 返回的姓名／邮箱。App 启动时会读取账户信息；登录失效且无法续期时才恢复登录按钮，临时网络故障不会直接退出已有登录。

点击 **登录 Link**，打开官方授权链接，在浏览器中输入 App 显示的授权短语并完成授权。独立 App 登录保存在 macOS Keychain 中，并支持自动续期。

已有且未过期的 CLI access token 可以只读复用；App 不修改其配置，也不使用其 refresh token。临时登录过期后，在 App 中建立独立登录，此后不需要 CLI 安装或配置。

当前个人项目使用 Stripe 开源实现中的公共 device-flow client 和 API 协议，连接名称为 **Link Card**，新授权不会附带电脑名；已有连接保留原名称，重新授权后才采用新名称。向其他用户分发正式产品时，应向 Stripe 注册自己的 OAuth client。

## 使用

- **请求 / 历史**：刷新、包含历史、选择请求、显示卡信息或在请求行确认取消；取消成功后清除该请求的卡信息。
- **创建**：加载付款方式，填写商家、URL、最小单位金额（USD $15 = 1500）、商品和至少 100 字符的用途，选择可用截止时间（默认一天以后），核对后提交。该值设置请求到期时间，实际卡片有效期由 Link 决定。
- 在 Link 中亲自批准购买。App 每两秒检查一次，最多等待十分钟，然后自动读取卡信息；也可手动刷新。
- 卡信息可以选中复制；缺失字段显示 `—`。响应仅在内存和临时网络会话中处理，不写成卡信息 JSON 文件。
- 关闭窗口会清除显示并停止批准检查。
- 历史页展示付款请求，不是商家最终结算流水。

完整操作和常见问题见[中文使用说明](docs/USAGE.zh-CN.md)。开发测试未执行真实购买或取消；真实账户验证仅进行了历史和付款方式的只读查询。

## 源码与构建

- `Source/Support.swift`：通用数据辅助类型。
- `Source/Model.swift`：账户、请求状态和异步操作。
- `Source/Localization.swift`：中英文界面文案。
- `Source/LinkCard.swift`：SwiftUI 界面和菜单栏入口。
- `Source/NativeLink.swift`：URLSession API、浏览器授权、凭证刷新和 Keychain 存储。

App 不启动子进程。使用 Xcode 在 Apple Silicon 上运行 `./build.sh` 构建，运行 `./test.sh` 执行离线模拟测试；测试不读取真实登录凭证，也不发送网络请求。

API 和授权协议参考 [Stripe Link SDK 与 CLI](https://github.com/stripe/link-cli)。Stripe 的 MIT 声明保留在 `STRIPE-LICENSE.txt`，并随 App 打包。

## App 图标

原图位于 `Assets/AppIcon.png`。构建脚本使用 macOS 自带的 `sips` 和 `iconutil` 生成多尺寸 `.icns` 并打包。原始生成提示保存在 `Assets/AppIcon.prompt.txt`。

## 许可证

项目采用 [MIT License](LICENSE)，版权 © 2026 Yuanxi Li。

API 和授权实现参考 Stripe 的开源 Link SDK 与 CLI；原始 MIT 版权及许可声明保存在 [STRIPE-LICENSE.txt](STRIPE-LICENSE.txt)，并包含在 App 中。

这是独立项目，不是 Stripe 或 Link 官方 App。
