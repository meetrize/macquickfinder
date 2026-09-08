# 同目录二次 Reveal 失败分析（2026-09-08）

## 用户期望

1. 冷启动 Reveal `…/Microsoft Excel.app` → 进入 `/Volumes/SSD4T/app` 并选中 Excel  
2. 再 Reveal `…/汽水音乐.app` → **新开标签**、立刻激活，并在列表中选中汽水音乐  

## 旧日志根因

```text
requestOpen warm-reuse-tab dir=/Volumes/SSD4T/app selection=…/汽水音乐.app
ContentView apply external selection …
```

- 路由走 **reuse**（同目录不新开标签），与产品期望不符。  
- 另有一次测试中二次 Reveal 时 `session=false`，误走 `cold-pending`，也不会新开标签。  

## 修复

1. 温启动（`session || hasRegisteredWindows`）**每次** `warm-new-tab ALWAYS`  
2. 去掉 `openExternalRevealTab`「同目录已有则 abort」  
3. 用 `lastMergedRevealTab` 激活新标签（避免 path 命中旧 Excel 页）  
4. 选中：`selection HIT/MISS/WAIT` 日志 + 延长重试 + `HIT-on-load`  
5. `tabsOnly` coalesce 不再收掉同目录业务标签  

## 自动化验收（open -R）

```text
cold-pending … Microsoft Excel.app
session established
selection HIT-on-load name=Microsoft Excel.app
warm-new-tab ALWAYS … selection=…/汽水音乐.app
bootstrap=initial … selection=…/汽水音乐.app
tab-generation merged … 汽水音乐
selection HIT-on-load name=汽水音乐.app
```
