[![Downloads](https://img.shields.io/github/downloads/boyl/onimusha-auto-issen/total?label=Downloads&color=blue)](https://github.com/boyl/onimusha-auto-issen/releases) [![Stars](https://img.shields.io/github/stars/boyl/onimusha-auto-issen?label=Stars)](https://github.com/boyl/onimusha-auto-issen/stargazers) [![Latest Release](https://img.shields.io/github/v/release/boyl/onimusha-auto-issen?label=Release)](https://github.com/boyl/onimusha-auto-issen/releases/latest) [![License](https://img.shields.io/github/license/boyl/onimusha-auto-issen?label=License)](https://github.com/boyl/onimusha-auto-issen/blob/HEAD/LICENSE)

# 自动一闪（Auto Issen）

《鬼武者：剑之道》独立 REFramework 自动反制 Mod。发布版本：0.1.21。运行文件保持不变，脚本内部标识仍为 0.1.21-test。

## 中文说明

五项功能分别提供开关：自动一闪、自动连锁一闪、抓取攻击自动反制、自动化劲、自动弹刀。化劲与弹刀同时开启时优先化劲。使用游戏原生判定窗口，不修改窗口倍率、伤害、血量或全局速度，不依赖原 Gameplay Tweaker DLL。

兼容基线：Steam 正式版 Build 24769601、TDB82。需要自行安装兼容的 [REFramework](https://github.com/praydog/REFramework)，本包不包含 REFramework。

安装：退出游戏，停用原 Gameplay Tweaker 和其他重复的自动反制脚本，将 ZIP 内的 `reframework` 文件夹合并到含 `OnimushaWotS.exe` 的游戏目录。启动游戏，在 REFramework → Script Generated UI → 一闪独立模块（Onimusha Issen Standalone）中选择功能。首次默认关闭；升级保留设置。

配置文件：`reframework/data/onimusha_issen_standalone.json`。关闭开关后恢复手动操作。卸载时仅删除本 Mod 的 `onimusha_issen.lua`、同名脚本目录及 `reframework/fonts/onimusha_issen`；配置可自行保留。

**实机验证：双鵺兽 Boss 战首次连锁一闪不触发，后续可触发；其他已测试场景正常。根因尚未确认，本版没有宣称修复此问题。** 未验证所有敌人、武器与游戏更新。请勿同时加载重复脚本。

本次为现有版本发布，功能与运行文件保持不变。1282 项模拟断言通过；模拟不能替代实机验收。正常一闪、化劲、弹刀及正常死亡已通过实机验证，双鵺兽首轮连锁仍是已知缺陷。

## English description

Standalone REFramework combat automation for Onimusha: Way of the Sword. Release version: 0.1.21. Runtime files are unchanged and retain the internal 0.1.21-test identifier.

Five independent switches: Auto Issen, Auto Chain Issen, Auto Counter Grab, Auto Kakei, and Auto Parry. Kakei takes priority when both Kakei and Parry are enabled. Uses native timing windows. Does not change timing multipliers, damage, health, or global game speed. Does not require the original Gameplay Tweaker DLLs.

Compatibility baseline: Steam retail Build 24769601, TDB82. Install a compatible [REFramework](https://github.com/praydog/REFramework) separately; it is not bundled.

Installation: exit the game, disable the original Gameplay Tweaker and duplicate combat automation scripts, then merge the archive's `reframework` folder into the game folder containing `OnimushaWotS.exe`. Start the game and select features under REFramework → Script Generated UI → Onimusha Issen Standalone. All switches default to off on a fresh installation. Existing settings are retained during upgrades.

Settings: `reframework/data/onimusha_issen_standalone.json`. Disabling a feature restores manual control. To uninstall, remove only `onimusha_issen.lua`, its matching script folder, and `reframework/fonts/onimusha_issen`. Keeping the configuration is optional.

**Tested in-game: the first Chain Issen in the twin Nue boss encounter fails to trigger, while later attempts work. Other tested encounters work normally. The root cause remains unconfirmed; this release does not claim to fix it.** Not all enemies, weapons, or game updates have been tested. Do not load duplicate scripts.

This release preserves the existing gameplay and runtime files. 1,282 simulated assertions passed; simulation does not replace in-game acceptance. Normal Issen, Kakei, Parry, and normal player death have been tested in-game. The first chain in the twin Nue encounter remains a known defect.

## REFramework 下载指引 / Download guide

- [官方 Nightly 下载 / Official nightly downloads](https://github.com/praydog/REFramework-nightly/releases)
- [官方安装文档 / Official installation documentation](https://cursey.github.io/reframework-book/#installation)

在下载页展开 Assets，选择支持本作的框架构建。当前官方 Nightly 框架文件名为 `REFramework.zip`；Source code 和 `csharp-api.zip` 不是 Lua 框架下载。仅将包中的 `dinput8.dll` 放到 `OnimushaWotS.exe` 同级目录。本 Mod 不包含 REFramework。已能正常运行本作 Lua Mod 的玩家可保留现有兼容框架；并非所有官方构建均已在本作验证。

Expand Assets and select a framework build compatible with this game. The current official nightly framework asset is `REFramework.zip`; Source code and `csharp-api.zip` are not the Lua runtime download. Copy only `dinput8.dll` beside `OnimushaWotS.exe`. REFramework is not bundled. You may keep an existing framework that already runs this game's Lua mods correctly. Not every official build has been verified with this game.

## 安装步骤 / Installation steps

1. 完全退出游戏。在 Steam 库右键游戏 → 管理 → 浏览本地文件，打开游戏根目录。
2. 按上述指引安装 REFramework。停用原 Gameplay Tweaker 和重复的自动反制脚本。
3. 解压本 Mod，将其中的 `reframework` 文件夹合并到游戏根目录，不要额外套一层 ZIP 名称目录或 `payload` 目录。
4. 启动游戏，在 REFramework → Script Generated UI → 一闪独立模块（Onimusha Issen Standalone）中开启所需功能。
5. 升级时覆盖脚本和字体，保留配置文件。首次安装各开关默认关闭。

English:

1. Exit the game. In Steam, right-click the game → Manage → Browse local files to open the game root.
2. Install REFramework as described above. Disable the original Gameplay Tweaker and duplicate combat automation scripts.
3. Extract this mod and merge its `reframework` folder directly into the game root. Do not add an extra archive-name or `payload` folder.
4. Start the game and enable the desired switches under REFramework → Script Generated UI → Onimusha Issen Standalone.
5. For updates, replace scripts and font while retaining the settings file. All switches default to off on a fresh installation.

## 安装目录及文件示意 / Installed folder layout

默认 Steam 路径 / Default Steam location:
`C:\Program Files (x86)\Steam\steamapps\common\OnimushaWotS`

其他 Steam 库以“浏览本地文件”打开的目录为准。For other Steam libraries, use the actual folder opened by Browse local files.

```text
OnimushaWotS/                         游戏根目录 / Game root
├── OnimushaWotS.exe                  游戏文件 / Existing game file
├── dinput8.dll                       REFramework，另行下载 / Separate download
└── reframework/
    ├── autorun/
    │   ├── onimusha_issen.lua        主脚本 / Main script
    │   └── onimusha_issen/
    │       ├── adapter.lua
    │       ├── contracts.lua
    │       ├── model.lua
    │       └── view.lua
    ├── fonts/
    │   └── onimusha_issen/
    │       ├── IssenCJK.ttf
    │       └── OFL.txt
    └── data/                        运行后生成 / Generated at runtime
        ├── onimusha_issen_standalone.json
        └── onimusha_issen_standalone_status.json
```

README 和 manifest 无需复制进游戏目录。README and manifest do not need to be copied into the game folder.

## 致谢 / Credits

感谢 praydog 及 REFramework 贡献者。Thanks to praydog and REFramework contributors. The bundled font is a renamed subset of Adobe Source Han Sans, distributed under the SIL Open Font License; see the included OFL.txt. Game assets and REFramework binaries are not bundled.
