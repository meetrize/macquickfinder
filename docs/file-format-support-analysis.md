# 全球行业文件格式全景分析 & 预览支持路线图

> 分析日期：2026-07-10
> 项目：MeoFind / macquickfinder

---

## 分析方法

按 **全球从业人数 × 格式使用频率 × 预览刚需程度** 综合排序，分为三个优先级。

当前已支持格式参考 `Sources/Explorer/CustomPreviewRuleStore.swift` 中的 `BuiltinPreviewExtensions`。

---

## 🔴 Tier 1 — 必须支持（覆盖全球 30 亿+用户）

| 行业 | 全球规模 | 关键格式 | 当前是否支持 |
|------|---------|---------|-------------|
| **办公商务** | ~20 亿白领 | `.docx` `.xlsx` `.pptx` `.pdf` `.csv` `.txt` `.rtf` | ✅ 大部分已支持 |
| **教育学术** | ~15 亿师生 | `.pdf` `.epub` `.mobi` `.docx` `.pptx` | ❌ **ePub/Mobi 缺失** |
| **互联网/IT** | ~3000 万开发者 | `.json` `.xml` `.yaml` `.md` `.sql` `.log` `.html` `.ini` `.toml` | ✅ 大部分已支持 |
| **普通消费者** | ~50 亿终端用户 | `.jpg` `.png` `.mp4` `.mp3` `.zip` `.rar` `.7z` | ⚠️ **rar/7z 缺失** |

### Tier 1 最急需补充：

| 格式 | 理由 |
|------|------|
| **`.epub`** | 全球电子书标准格式，Kindle/Kobo/Apple Books 通用，15 亿+学生群体刚需 |
| **`.rar` `.7z`** | 全球压缩包三巨头之二，当前仅支持 zip/tar |
| **`.aac` `.flac` `.m4a`** | 主流音频格式，Apple Music / 无损音乐标配 |
| **`.mkv` `.webm` `.avi`** | 主流视频封装格式 |
| **`.rtf`** | 跨平台富文本格式，macOS TextEdit 原生格式 |
| **`.toml`** | 现代配置文件标准（Rust/Python 生态），开发者刚需 |

---

## 🟡 Tier 2 — 高价值（覆盖全球 5-15 亿专业用户）

| 行业 | 全球从业者 | 关键格式 | 理由 |
|------|-----------|---------|------|
| **设计创意** | ~5000 万 | `.psd` `.ai` `.sketch` `.fig` `.afdesign` `.xd` | Adobe 生态 + Sketch/Figma 主流 |
| **工程制造** | ~1 亿工程师 | `.stp/.step` `.stl` `.igs` `.dwg` `.dxf` `.obj` `.fbx` `.gltf/.glb` | CAD/CAM/3D 打印工业标准 |
| **建筑建造** | ~1 亿从业者 | `.dwg` `.dxf` `.ifc` `.rvt` `.skp` `.3ds` | AutoCAD + Revit + SketchUp 铁三角 |
| **摄影摄像** | ~3000 万 | `.cr2/.cr3` `.nef` `.arw` `.dng` `.rw2` `.orf` `.raf` | Canon/Nikon/Sony/Fuji/Panasonic RAW |
| **财务会计** | ~2 亿从业者 | `.xlsx` `.csv` `.tsv` `.numbers` `.ods` `.qfx/.ofx` | Excel + iWork + 财务交换格式 |
| **GIS 地理信息** | ~1000 万 | `.geojson` `.kml/.kmz` `.gpx` `.shp` `.geotiff` | 地图、测绘、LBS |

### Tier 2 最急需补充：

| 格式 | 理由 |
|------|------|
| **`.dwg` `.dxf`** | AutoCAD 全球 1 亿+授权用户，工程设计第一格式 |
| **`.stp/.step`** | ISO 10303 国际标准，跨 CAD 软件通用交换格式 |
| **`.stl`** | 3D 打印事实标准，全球 Maker/制造都用 |
| **`.gltf/.glb`** | Web 3D 标准（Khronos），Apple Vision Pro / AR 生态核心 |
| **RAW 照片格式** | 摄影师群体刚需，当前仅借 QuickLook 间接支持 |
| **`.gpx`** | 户外运动/测绘 GPS 轨迹通用格式 |
| **`.geojson`** | Web 地图数据标准，开发者/地理信息行业通用 |

---

## 🟢 Tier 3 — 行业专用但用户基数大（覆盖 5000 万 - 3 亿）

| 行业 | 全球从业者 | 关键格式 | 理由 |
|------|-----------|---------|------|
| **医疗影像** | ~5000 万医护 | `.dicom` `.nifti` | 医学影像全球标准 |
| **科研学术** | ~2000 万 | `.fits` `.hdf5` `.netcdf` `.mat` `.ipynb` `.cif` `.pdb` | 天文/气候/生物/化学 |
| **电子工程** | ~3000 万 | `.pcb` `.sch` `.brd` `.gerber` | EDA/PCB 设计 |
| **字体设计** | ~500 万专业 + 广泛使用 | `.ttf` `.otf` `.woff2` | 字体预览价值极高 |
| **邮件归档** | 通用 | `.eml` `.msg` `.mbox` | 几乎人人有邮件存档 |
| **字幕/语言** | 通用 | `.srt` `.vtt` `.ass` | 视频字幕，多语言群体 |
| **数据科学** | ~1000 万 | `.parquet` `.avro` `.feather` `.ipynb` | 大数据/ML 标配 |
| **法律政务** | ~5000 万 | `.odt` `.ods` `.odp` | ODF 开放文档标准，欧盟政府强制 |
| **财务个人** | 数十亿 | `.qfx` `.ofx` `.qif` | 银行账单/个人财务 |

### Tier 3 最值得考虑：

| 格式 | 理由 |
|------|------|
| **`.ttf` `.otf` `.woff2`** | 字体预览是 Finder 缺失的痛点功能，设计师群体高度需要 |
| **`.eml` `.msg`** | 邮件文件几乎人人有，预览邮件正文非常实用 |
| **`.srt` `.vtt`** | 视频字幕文件，国际化群体刚需 |
| **`.dicom`** | 医学影像，虽然专业但用户基数大（全球医生 + 患者查看自己影像） |
| **`.ipynb`** | Jupyter Notebook，数据科学/教育标配 |
| **`.epub` `.mobi`** | 电子书（已在 Tier 1 提及，但重度归类到此处也可） |

---

## 📊 按格式分类的优先级矩阵

```
                    用户覆盖广度 →
                    数十亿   数亿   数千万   数百万
格式复杂度 ↓
┌─────────────────────────────────────────────────┐
│ 文本解析    │ txt,csv  epub   eml,srt  ipynb    │
│ (低复杂度)  │ json,md   rtf   gpx,ttf  odt      │
│             │ yaml,log  ini   geojson  toml     │
├─────────────┼───────────────────────────────────┤
│ 媒体解码    │ jpg,mp4   flac  cr2,nef  fits     │
│ (中复杂度)  │ png,mp3   mkv   dng,arw  dicom    │
│             │ svg,webp  aac   webm     heif     │
├─────────────┼───────────────────────────────────┤
│ 复杂渲染    │ pdf       dwg   step     ifc       │
│ (高复杂度)  │ docx,xlsx stl   gltf     rvt       │
│             │ pptx      psd   fbx      mat       │
└─────────────────────────────────────────────────┘
```

---

## 🎯 建议：优先补充路线图

基于 **"用户覆盖 × 实现难度 × 当前缺失"** 三维评分，分三期推进：

### 🥇 第一期（即刻高价值，实现成本低）

| 格式 | 类型 | 覆盖人群 | 实现方式 |
|------|------|---------|---------|
| `.rar` `.7z` | 压缩包 | ~30 亿 | 集成 libarchive / unrar |
| `.epub` `.mobi` | 电子书 | ~15 亿 | Zip 内 HTML 解析渲染 |
| `.rtf` | 富文本 | ~20 亿 | AppKit NSAttributedString 原生支持 |
| `.toml` | 配置 | ~3000 万 | 纯文本高亮 |
| `.srt` `.vtt` | 字幕 | ~10 亿 | 纯文本 + 时间轴解析 |
| `.gpx` | GPS | ~5 亿 | XML 解析 + 地图预览 |
| `.ttf` `.otf` `.woff2` | 字体 | ~5 亿 | CoreText/AppKit 字体渲染预览 |
| `.eml` | 邮件 | ~30 亿 | MIME 解析提取正文 |

### 🥈 第二期（高用户覆盖，中等实现难度）

| 格式 | 类型 | 实现方式 |
|------|------|---------|
| `.stl` `.step/.stp` `.gltf/.glb` | 3D/CAD | SceneKit/Metal 3D 渲染 |
| `.dwg` `.dxf` | CAD | libredwg 或 QuickLook 委托 |
| `.geojson` `.kml` | GIS | JSON/XML 解析 + MapKit |
| `.aac` `.flac` `.m4a` | 音频 | AVFoundation |
| `.mkv` `.webm` `.avi` | 视频 | AVFoundation / FFmpeg |
| `.ipynb` | Notebook | JSON 解析 + Markdown 渲染 |
| `.numbers` `.pages` `.keynote` | iWork | ZIP 内预览图提取 或 QuickLook |

### 🥉 第三期（行业深度，实现成本较高）

| 格式 | 类型 | 实现方式 |
|------|------|---------|
| `.dicom` `.nifti` | 医学影像 | GDCM / ITK 库 |
| `.fits` | 天文 | CFITSIO 库 |
| `.ifc` | BIM | IfcOpenShell / 简化几何提取 |
| `.parquet` | 数据 | Arrow C++ 库 |
| `.fbx` `.obj` | 3D | Assimp / ModelIO |
| `.xmind` | 思维导图 | XML/ZIP 解析 |
| `.cif` `.pdb` | 化学/生物 | 分子结构 3D 可视化 |

---

## 📌 特别决策建议

### 1. `.epub` 优先级极高

本质是 ZIP 包 + HTML，实现成本很低但覆盖 15 亿+教育用户。竞争产品（如 Eagle、Bridge）几乎都不支持 ePub 直接预览。

### 2. STL / STEP / GLTF 3D 预览是差异化杀手

如果能在 Finder 替代品里直接预览 3D 模型，工程、制造、3D 打印三个行业加起来超过 2 亿用户会直接选择你。macOS 的 QuickLook 默认也不支持这些格式。

### 3. 字体预览（TTF / OTF）是设计行业长期痛点

macOS Finder 的字体预览需要双击打开 Font Book。能直接在文件管理器预览字体样张是强需求。

### 4. 邮件 `.eml` 预览

几乎人人有，但几乎没人做。实现起来也只是 MIME 解析 + 渲染 HTML/纯文本正文。

---

## 附录：当前已支持格式速查

参见 `Sources/Explorer/CustomPreviewRuleStore.swift` → `BuiltinPreviewExtensions`：

| 类别 | 已支持格式 |
|------|-----------|
| 图片 | jpg, jpeg, png, gif, tiff, bmp, heic, webp, svg, eps, epsf, epsi |
| 图片(QuickLook) | psd, ai, dxf |
| 媒体 | mp4, mov, mp3, wav |
| Office | doc, docx, xls, xlsx, ppt, pptx |
| PDF | pdf |
| 文本/代码 | txt, md, swift, java, py, js, ts, go, rs, kt, php, rb, html, css, json, xml, c, cpp, h, sh, bash, zsh, yaml, yml, vue, config, ini, gitignore, properties, log, sql, csv, applescript |
| 压缩包 | zip, tar, tar.gz, tgz |
