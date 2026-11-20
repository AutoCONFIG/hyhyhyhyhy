# 每日固件构建

`.github/workflows/firmware.yml` 是唯一入口，每天北京时间 02:00 定时触发。推送到 `master` 的 `.github/` 改动也会触发。矩阵并行运行三条源码构建和两条 ImageBuilder 构建。
23、24 系列入口已移除；25 系列保留 x86 和 R66s 两条路线，abt3000 继续使用源码构建。
设备与软件包选项位于 `.github/configs/`；abt3000 仍先读取上游 `defconfig/mt7981-ax3000.config`，再追加本仓库的选项。

ImageBuilder 路线使用 ImmortalWrt 25.12 的官方预编译内核、驱动和软件包，只负责快速组装镜像；源码路线继续使用 Buildroot 完整编译。两条路线的产物、缓存和跳过记录按设备与路线隔离。

每天会检查主源码、OpenClash、feeds、配置和构建脚本版本。输入一致且上次的 3 份产物仍有效时，跳过构建，运行摘要提供上次产物的链接。
输入改变、产物过期或查询失败时，重新构建。源码下载和 ccache 编译缓存跨天保存；ImageBuilder 缓存发行包、OpenClash 和已下载的软件包。

失败后在 GitHub Actions 中选择 **Re-run failed jobs**：

- 若失败检查点保存成功，会恢复同一次运行的完整 `openwrt/` 目录，包括源码、feeds、配置、下载文件、工具链及已完成的编译产物，继续执行 `make`。
- 重跑使用检查点中的源码，不会重新拉取发生变化的上游版本，也不会重复应用 RAID 补丁。
- 已经编译成功、仅上传失败时，恢复检查点后直接重新上传。上传允许覆盖同次运行的同名产物。

源码检查点只在失败时保存，并按设备、路线和运行编号隔离；新一天的运行不会恢复旧的中间产物，但会恢复 ccache。ImageBuilder 重试使用下载缓存重新组装镜像。
GitHub 缓存配额、缓存清理或强制取消可能使检查点不可用，此时会正常从头构建；完整固件构建目录较大，需要留意仓库的 Actions 缓存空间。

本地检查：`bash tests/build-fingerprint.sh`、`bash tests/config-fingerprint.sh`、`bash tests/configure.sh`、`bash tests/previous-build.sh`（需要 `jq`）、`bash tests/imagebuilder-packages.sh`、`bash tests/imagebuilder-prepare.sh`。
ImageBuilder 校验发行包和 OpenClash 的 SHA-256，检查 target/profile 和最终 OpenClash 版本；缺少依赖或所选软件包时构建失败，不会静默省略。
