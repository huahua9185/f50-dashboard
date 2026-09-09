# F50 Dashboard

ZTE F50 Pro 随身路由器的 macOS 菜单栏仪表盘。不用打开路由器网页，就能实时看到信号、
速率、流量和接入终端。

菜单栏常驻显示信号格和实时上下行速率，点击弹出快捷面板，需要看全貌时再打开仪表盘窗口。

> **这是第三方非官方工具**，与中兴通讯（ZTE）没有任何关联，也未获其授权或认可。
> ZTE、F50 Pro 等名称均为其各自所有者的商标，此处仅用于说明本工具适配的设备型号。
> 软件按「原样」提供，使用风险自负。

## 安装

从 [Releases](../../releases) 下载 DMG，拖进「应用程序」即可。首次运行如果系统提示
无法验证开发者，说明下载的是未公证版本，请改用 Releases 里的正式包。

需要 macOS 15 或更高版本。

## 使用

启动后图标常驻菜单栏。**如果看不到图标，多半是菜单栏被占满了**（尤其是刘海屏），
腾出空间或用 Ice 这类工具收纳其他图标即可。

面板里可以开启开机自启（登录项，随时能在「系统设置 › 通用 › 登录项」里关掉）。

## 适用范围

只在 ZTE F50 Pro（固件 `F50ProV1.0.0B25`，硬件 `F50ProHW1.0`）上实测过。
其他中兴 MiFi 型号的 goform 接口大同小异，可能可用，但字段名未必一致。

## 数据来源

设备的 Web 管理页背后是一组 goform 接口，返回纯 JSON，**读取无需登录**，但必须带
`Referer` 头，否则设备拒绝响应：

```
GET http://192.168.0.1/goform/goform_get_cmd_process?isTest=false&multi_data=1&cmd=<字段,字段,...>
Referer: http://192.168.0.1/index.html
```

已确认可用的字段见 `Sources/F50Dashboard/Model/F50Client.swift`。

几个实测得到的坑：

- 同一字段的类型不固定（数字 / 字符串），无数据时还会退化成空字符串，
  所以统一用 `JSONValue` 宽松解码。
- 请求 `msisdn`，设备回的 key 却是 `sim_msisdn`。
- `realtime_tx_bytes` / `realtime_rx_bytes` 这个固件恒为 0，本次会话流量拿不到，
  界面改用 `monthly_*` 字段。
- `Z5g_SINR`、`wifi_chip_temp`、`WPAPSK1_encode` 等字段需要登录态才有值，当前未实现登录。

## 构建

```bash
./build-app.sh          # 编译 + 打包 + ad-hoc 签名，产物在 build/
cp -R "build/F50 Dashboard.app" /Applications/
```

图标由脚本生成，改配色后重跑：

```bash
swift Tools/generate-icon.swift Resources
cd Resources && iconutil -c icns AppIcon.iconset -o AppIcon.icns
```

## 环境变量

| 变量 | 作用 |
|---|---|
| `F50_LOGIN_ITEM=1` / `=0` | 命令行开关开机自启 |
| `F50_SHOW_DASHBOARD=1` | 启动时直接打开仪表盘窗口 |

## 排查

轮询日志是 debug 级别，不落盘，要用 stream 看：

```bash
/usr/bin/log stream --predicate 'subsystem == "local.majun.f50dashboard"' --level debug
```

菜单栏图标不见了，多半是被刘海挤掉了 —— 启动时会记录状态项的实际坐标，
如果 x 落在屏幕中央区域就是这个原因，需要腾出菜单栏空间。

## 已知限制

- 设备地址硬编码 `192.168.0.1`（`F50Client.host`），改过网段需要改代码。
- 未实现登录，拿不到需要鉴权的字段。
