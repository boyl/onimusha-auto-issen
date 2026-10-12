# 自动一闪（Auto Issen）

《鬼武者：剑之道》独立 REFramework 自动反制 Mod。当前版本：0.1.21-test（测试版）。

## 中文说明

五项功能分别提供开关：自动一闪、自动连锁一闪、抓取攻击自动反制、自动化劲、自动弹刀。化劲与弹刀同时开启时优先化劲。使用游戏原生判定窗口，不修改窗口倍率、伤害、血量或全局速度，不依赖原 Gameplay Tweaker DLL。

兼容基线：Steam 正式版 Build 24769601、TDB82。需要自行安装兼容的 [REFramework](https://github.com/praydog/REFramework)，本包不包含 REFramework。

安装：退出游戏，停用原 Gameplay Tweaker 和其他重复的自动反制脚本，将 ZIP 内的 `reframework` 文件夹合并到含 `OnimushaWotS.exe` 的游戏目录。启动游戏，在 REFramework → Script Generated UI → 一闪独立模块（Onimusha Issen Standalone）中选择功能。首次默认关闭；升级保留设置。

配置文件：`reframework/data/onimusha_issen_standalone.json`。关闭开关后恢复手动操作。卸载时仅删除本 Mod 的 `onimusha_issen.lua`、同名脚本目录及 `reframework/fonts/onimusha_issen`；配置可自行保留。

**已知问题：根据用户实机反馈，双鵺兽 Boss 战首次连锁一闪不触发，后续可触发；其他已测试场景正常。根因尚未确认，本版没有宣称修复此问题。** 未验证所有敌人、武器与游戏更新。请勿同时加载重复脚本。

本次为现有版本发布，功能与运行文件保持不变。1282 项模拟断言通过；模拟不能替代实机验收。正常一闪、化劲、弹刀及正常死亡曾获用户实测反馈，双鵺兽首轮连锁仍是已知缺陷。

## English description

Standalone REFramework combat automation for Onimusha: Way of the Sword. Version: 0.1.21-test (test release).

Five independent switches: Auto Issen, Auto Chain Issen, Auto Counter Grab, Auto Kakei, and Auto Parry. Kakei takes priority when both Kakei and Parry are enabled. Uses native timing windows. Does not change timing multipliers, damage, health, or global game speed. Does not require the original Gameplay Tweaker DLLs.

Compatibility baseline: Steam retail Build 24769601, TDB82. Install a compatible [REFramework](https://github.com/praydog/REFramework) separately; it is not bundled.

Installation: exit the game, disable the original Gameplay Tweaker and duplicate combat automation scripts, then merge the archive's `reframework` folder into the game folder containing `OnimushaWotS.exe`. Start the game and select features under REFramework → Script Generated UI → Onimusha Issen Standalone. All switches default to off on a fresh installation. Existing settings are retained during upgrades.

Settings: `reframework/data/onimusha_issen_standalone.json`. Disabling a feature restores manual control. To uninstall, remove only `onimusha_issen.lua`, its matching script folder, and `reframework/fonts/onimusha_issen`. Keeping the configuration is optional.

**Known issue: user testing reports that the first Chain Issen in the twin Nue boss encounter fails to trigger, while later attempts work. Other tested encounters work normally. The root cause remains unconfirmed; this release does not claim to fix it.** Not all enemies, weapons, or game updates have been tested. Do not load duplicate scripts.

This release preserves the existing gameplay and runtime files. 1,282 simulated assertions passed; simulation does not replace in-game acceptance. User tests previously confirmed normal Issen, Kakei, Parry, and normal player death. The first chain in the twin Nue encounter remains a known defect.

## 致谢 / Credits

感谢 praydog 及 REFramework 贡献者。Thanks to praydog and REFramework contributors. The bundled font is a renamed subset of Adobe Source Han Sans, distributed under the SIL Open Font License; see the included OFL.txt. Game assets and REFramework binaries are not bundled.
