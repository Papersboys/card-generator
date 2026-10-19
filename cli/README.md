# link-card CLI

[中文](#中文)

Interactive terminal helper for Link spend requests. This is the existing shell/Python command, packaged with all its helper files, not a standalone native executable. The macOS app does not need these dependencies.

Requires Bash, Python 3, jq, and Stripe's `link-cli` on PATH. Install and authenticate first:

```sh
brew install python jq
npm install -g @stripe/link-cli --registry=https://registry.npmjs.org/
link-cli auth login
```

Download `link-card-cli.tar.gz` from GitHub Releases and extract it. From its extracted `link-card-cli` directory:

```sh
./install.sh
export PATH="$HOME/bin:$PATH"
link-card --help
```

The installer puts `link-card` and its helpers in `~/.local/lib/link-card`, and adds a launcher at `~/bin/link-card`. It backs up an existing launcher before replacing it. Add the PATH line to `~/.zshrc` if needed. To remove it, delete `~/bin/link-card` and `~/.local/lib/link-card`.

```sh
link-card create                 # Select payment method, enter details, confirm, approve in Link
link-card show                   # Select an active request and show card details
link-card show lsrq_EXAMPLE       # Show a specific request
link-card history                # Select from active and past requests
link-card cancel                 # Select a request; requires typing yes
link-card show --delete lsrq_EXAMPLE  # Remove saved JSON after display
```

Card number, CVC/CVV, expiration, billing address and request metadata appear in a colored table when returned by Link. `NO_COLOR=1` disables colors. Full credentials are visible in terminal scrollback. `show` saves a private JSON response in the temporary directory; use `--delete` to remove it after display, or `--path` to print its location. Creation requires review and confirmation, and approval is completed in Link. Cancellation requires explicit confirmation. No login or payment data is included in this archive.

## 中文

交互式终端工具，包含现有的 `link-card` 入口及全部辅助文件；它是 shell/Python 脚本包，不是免依赖的原生可执行文件。macOS App 不需要这些依赖。

依赖 Bash、Python 3、jq、Stripe `link-cli`。先按上方命令安装依赖并执行 `link-cli auth login` 登录。下载 Release 中的 `link-card-cli.tar.gz`，解压后进入 `link-card-cli` 文件夹，运行 `./install.sh`，并确保 `~/bin` 在 PATH 中。

- `link-card create`：选择付款方式，填写购买信息，确认后创建，再在 Link 中批准。
- `link-card show [lsrq_请求ID]`：交互选择或直接查看卡信息。
- `link-card history`：包含历史请求供选择。
- `link-card cancel [lsrq_请求ID]`：选择或指定请求，输入 yes 后取消。

Link 返回的卡号、CVC/CVV、有效期、账单地址及请求信息会显示为彩色表格；缺失字段显示 `—`。完整卡信息会保留在终端回滚记录中。`show` 默认在临时目录保存权限受限的 JSON；加 `--delete` 可在显示后删除，加 `--path` 可显示文件路径。安装程序会备份已有的 `~/bin/link-card`。压缩包不包含登录或付款数据。

Apache License 2.0; see LICENSE.
