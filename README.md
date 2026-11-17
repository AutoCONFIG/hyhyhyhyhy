# 每日固件构建

7 个原有入口工作流保留名称、master 分支触发和每日定时，统一调用 `.github/workflows/build-firmware.yml`。
设备与软件包选项位于 `.github/configs/`；24、25 系列中相同的配置共用文件。
abt3000-ap 仍先读取上游 `defconfig/mt7981-ax3000.config`，再追加本仓库的选项。

每天会检查主源码、OpenClash、feeds 和本仓库版本。输入一致且上次的 3 份产物仍有效时，跳过构建，运行摘要提供上次产物的链接。
输入改变、产物过期或查询失败时，重新构建。下载的源码包使用独立缓存，在同一源码系列的设备间复用。

失败后在 GitHub Actions 中选择 **Re-run failed jobs**：

- 若失败检查点保存成功，会恢复同一次运行的完整 `openwrt/` 目录，包括源码、feeds、配置、下载文件、工具链及已完成的编译产物，继续执行 `make`。
- 重跑使用检查点中的源码，不会重新拉取发生变化的上游版本，也不会重复应用 RAID 补丁。
- 已经编译成功、仅上传失败时，恢复检查点后直接重新上传。上传允许覆盖同次运行的同名产物。

检查点只在失败时保存，并按工作流和运行编号隔离；新一天的运行不会恢复旧的中间产物。
GitHub 缓存配额、缓存清理或强制取消可能使检查点不可用，此时会正常从头构建；完整固件构建目录较大，需要留意仓库的 Actions 缓存空间。

本地检查：`bash tests/build-fingerprint.sh`、`bash tests/configure.sh`、`bash tests/previous-build.sh`（最后一项需要 `jq`）。
