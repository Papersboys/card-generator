# Link Card local AI integration / 本地 AI 接入

Install the latest LinkCard.app in /Applications, run it, sign in, and explicitly enable Local MCP in the panel. It is off at every launch. Use mcp-config.json with a client that supports local stdio MCP. The included standalone binary is an alternative to the binary already inside the App; change the command to its actual absolute path if using it. It requires the running App and does not read or refresh credentials itself. Apple Silicon/macOS 13+; no Node, Python or link-cli runtime required.

Read the [English guide](https://papersboys.github.io/card-generator/guide.en.html#ai-mcp) or [中文指南](https://papersboys.github.io/card-generator/guide.html#ai-mcp). Claude Desktop uses a mcpServers object; Codex uses a TOML mcp_servers entry. Do not paste either format into the other client. Install skills/link-card only in the skill directory supported by your chosen client, after review.

The Unix socket is restricted to your macOS user (directory 700/socket 600 plus peer UID checks). **Any process running as that user can invoke this opt-in interface.** No TCP port, remote endpoint, full card details, tokens, delegated approval or checkout submission are exposed. Disabling prevents new calls; it cannot undo a mutation already sent to Link. Create and cancel tools require confirmed=true for reviewed human intent. Link approval remains with the human.

本地 MCP 每次启动默认关闭；需要 App 正在运行并已登录。当前 macOS 用户的进程均可访问开启后的接口，不限于某一个 AI 客户端。关闭后拒绝新调用，不能撤回已经发给 Link 的请求。AI 只读请求元数据，完整卡信息仍在 App 中查看。不要把本地接口转发到公网，不需要填写任何 API Key 或登录令牌。

The AI Catalog uses a draft specification. Its MCP configuration artifact has a vendor-specific media type; discovery does not automatically install, trust or authorize this software. No A2A service or standardized MCP Server Card is claimed.

Licensed under Apache License 2.0. Independent project, not affiliated with Stripe/Link.
