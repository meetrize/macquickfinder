# Explorer

一款使用 SwiftUI 构建的快速、原生 macOS Finder 替代工具。

[English](README.md)

## 功能特性

- 快速的文件浏览与搜索
- 现代化的 SwiftUI 界面
- 侧边栏快速访问常用位置
- 分栏式文件列表，支持多种排序方式
- 文件预览
- 新建文件夹
- 双击使用默认应用打开文件

## 构建应用

使用项目自带的脚本构建并运行：

```bash
./build_and_run.sh
```

该脚本会：

1. 以 Release 模式构建项目
2. 生成 macOS 应用包（.app）
3. 启动应用

## 系统要求

- macOS 13.0 或更高版本
- Swift 6.0 或更高版本

## 开发说明

本应用基于以下技术构建：

- Swift Package Manager 管理依赖
- SwiftUI 构建用户界面
- Foundation 与 AppKit 处理文件系统操作

## 性能优化

应用包含多项性能优化：

- 使用后台线程异步加载文件
- 通过 FileManager 高效枚举文件
- 资源的懒加载
- 文件属性的合理缓存
