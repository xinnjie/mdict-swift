# 贡献指南

## Toolchain Requirements

工具链版本以 [mise.toml](mise.toml) 为准。Swift 和 Xcode 由系统及
`xcode-select` 管理。

## Development setup

```bash
mise install
mise x -- npm ci
```

### Build and test

```bash
make build
make test
```

### Check and fix

```bash
make check
make fix
```

### Git hooks

本仓库使用 [hk](https://github.com/jdx/hk) 在 `pre-commit` 时对暂存文件执行检查。

首次 clone 项目需要安装钩子：

```bash
mise x -- hk install --mise
```

跳过钩子（仅在必要时）：

```bash
HK=0 git commit ...
# 或
git commit --no-verify ...
```

## Pull requests

- 一个 Pull Request 尽量只处理一个问题
- 新功能必须包含测试
- 修改公共 API 时必须更新文档

## Commit messages

使用 Conventional Commits：

```text
feat:
fix:
refactor:
docs:
```

## Repository constraints

- 除非依赖发生变化，否则不要更新 Swift lock 文件
- 除非任务确实需要，否则避免添加新依赖
- 除非明确要求，否则保持公共 API 兼容性
- 不要进行与当前任务无关的重构

## Testing

- 使用 Swift Testing 编写测试
- 单元测试面向行为，不面向实现细节

## Coding Style

- 使用 Swift 6
- 代码使用英文编写
- 并发代码优先使用结构化并发（`async`/`await`、Actor、`TaskGroup`）
