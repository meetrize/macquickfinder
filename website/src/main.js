import './styles/main.css';

const STORAGE_LANG = 'meofind-landing-lang';
const STORAGE_THEME = 'meofind-landing-theme';

/** @type {Record<string, Record<string, string>>} */
const i18n = {
  zh: {
    'nav.features': '特性',
    'nav.preview': '预览',
    'nav.automation': '自动化',
    'nav.trust': '技术',
    'nav.download': '下载',
    'nav.downloadBtn': '免费下载',
    'theme.toLight': '切换到浅色外观',
    'theme.toDark': '切换到深色外观',
    'hero.badge': 'macOS 原生 · Swift 构建',
    'hero.subtitle': '在原生 macOS 上，把浏览、预览与脚本自动化装进一个窗口。少开三个窗口，多干一件事。',
    'hero.cta.download': '免费下载 macOS 版',
    'hero.cta.demo': '观看演示',
    'hero.meta.os': 'macOS 13+',
    'hero.meta.native': 'Swift 原生',
    'hero.meta.i18n': '中英双语',
    'mock.preview': '实时预览',
    'mock.output': '$ snippet 完成 · Job #1',
    'mock.previewLabel': '预览',
    'mock.snippetsLabel': 'Snippets',
    'mock.outputLabel': '输出',
    'story.eyebrow': '为什么需要 MeoFind',
    'story.title': '三个场景，一个窗口搞定',
    'story.desc': '从找文件到看内容再到跑脚本，不必在 Finder、预览器和终端之间来回切换。',
    'story.1.pain': '文件夹里翻找太慢',
    'story.1.title': '找文件',
    'story.1.text': '直接打字即过滤，Tab 循环匹配项并同步预览；面包屑与路径历史让跳转行云流水。',
    'story.2.pain': 'Space 预览不够用',
    'story.2.title': '看内容',
    'story.2.text': '右侧实时预览代码、PDF、图片与音视频，自带工具栏操作，不必离开浏览器。',
    'story.3.pain': '重复操作靠记忆',
    'story.3.title': '做操作',
    'story.3.text': 'Snippets 保存常用脚本，变量自动展开；输出面板显示 Job 结果与交互式命令行。',
    'features.eyebrow': '功能全景',
    'features.title': '按你的工作流分类',
    'features.desc': '从浏览导航到预览、自动化与远程访问，MeoFind 把效率工具装进熟悉的文件管理器界面。',
    'feat.browse.title': '浏览与导航',
    'feat.browse.tag': '输入即搜，路径随心跳',
    'feat.browse.1': '列表与缩略图双视图，滑块调节图标大小',
    'feat.browse.2': '面包屑跳转、路径编辑、前进后退与历史记录',
    'feat.browse.3': '拖放打开、外部新窗口、空白处双击自定义行为',
    'feat.sidebar.title': '侧边栏',
    'feat.sidebar.tag': '常用位置，触手可及',
    'feat.sidebar.1': '收藏夹固定常用目录',
    'feat.sidebar.2': '设备区动态显示已挂载磁盘与移动硬盘',
    'feat.sidebar.3': '废纸篓浏览、放回原处与清空',
    'feat.preview.title': '全能预览',
    'feat.preview.tag': '选中即看，不必再按 Space',
    'feat.preview.1': '文本/代码高亮、Markdown/HTML 双模式',
    'feat.preview.2': '图片缩放旋转、PDF 翻页、音视频播放',
    'feat.preview.3': '压缩包目录、电子表格、Quick Look 回退',
    'feat.previewBrowser.title': '预览浏览器',
    'feat.previewBrowser.tag': '胶片条快速切换',
    'feat.previewBrowser.1': '底部胶片条浏览当前目录全部文件',
    'feat.previewBrowser.2': '上一项/下一项，独立预览窗口 ⌘⌥P',
    'feat.previewBrowser.3': '自定义预览规则，按扩展名指定方式',
    'feat.snippets.title': 'Snippets',
    'feat.snippets.tag': '把重复操作写成片段',
    'feat.snippets.1': 'Shell、Python、AppleScript 多类型支持',
    'feat.snippets.2': '%p 路径、%d 目录等变量自动展开',
    'feat.snippets.3': '作用域过滤、导入导出 JSON 备份',
    'feat.output.title': '输出面板',
    'feat.output.tag': '脚本与终端，底部一体',
    'feat.output.1': '每次执行一个 Job 标签，支持并行多任务',
    'feat.output.2': '交互式 zsh 命令框，目录随地址栏同步',
    'feat.output.3': '流式输出、查找高亮、复制与终止任务',
    'feat.remote.title': '远程服务器',
    'feat.remote.tag': 'FTP 等协议直连',
    'feat.remote.1': '连接远程服务器，像本地文件夹一样浏览',
    'feat.remote.2': '最近连接快速回访',
    'feat.remote.3': '与收藏夹、预览、Snippets 无缝配合',
    'feat.layout.title': '布局与效率',
    'feat.layout.tag': '窗口随你塑形',
    'feat.layout.1': '预览、Snippets、输出面板独立折叠与调比',
    'feat.layout.2': '窗口贴靠半屏/全屏，多窗口并行',
    'feat.layout.3': '工具栏自定义，添加「用指定 App 打开」按钮',
    'gallery.eyebrow': '界面一览',
    'gallery.title': '截图与演示',
    'gallery.desc': '以下为占位区域，补充截图与视频后自动展示。',
    'gallery.main': '主界面三栏布局',
    'gallery.browse': '列表 / 缩略图',
    'gallery.preview': '预览工具栏',
    'gallery.snippets': 'Snippets 面板',
    'gallery.output': '输出 Job',
    'gallery.remote': '远程连接',
    'video.eyebrow': '视频演示',
    'video.title': '60 秒看懂 MeoFind',
    'video.desc': '从浏览到预览再到 Snippet 执行，一条链路演示完整工作流。',
    'video.main.title': '完整工作流演示',
    'video.main.desc': '搜索 → 预览 PDF → 运行 Snippet → 查看 Job 输出',
    'video.main.placeholder': '视频待补充 · demo-main.mp4',
    'video.preview.title': '多格式预览快剪',
    'video.preview.desc': '代码、图片、PDF、音视频预览能力一览',
    'video.preview.placeholder': '视频待补充 · demo-preview.mp4',
    'workflow.eyebrow': '一条链路',
    'workflow.title': '从选中到执行，五步完成',
    'workflow.1.title': '选中文件',
    'workflow.1.desc': '列表或缩略图中点选',
    'workflow.2.title': '右侧预览',
    'workflow.2.desc': '即时查看内容',
    'workflow.3.title': '运行 Snippet',
    'workflow.3.desc': '⌘⇧S 打开片段面板',
    'workflow.4.title': 'Job 输出',
    'workflow.4.desc': '⌘J 查看执行结果',
    'workflow.5.title': '继续操作',
    'workflow.5.desc': '终端或命令框接力',
    'trust.eyebrow': '技术底座',
    'trust.title': '原生、快速、可信赖',
    'trust.1.title': 'Swift 原生',
    'trust.1.text': 'SwiftUI + AppKit，macOS 13+',
    'trust.2.title': '异步加载',
    'trust.2.text': '后台枚举、缩略图磁盘缓存',
    'trust.3.title': '双语界面',
    'trust.3.text': '简体中文与英文完整支持',
    'trust.4.title': '默认打开方式',
    'trust.4.text': '可设为系统默认文件夹查看器',
    'download.eyebrow': '立即体验',
    'download.title': '下载 MeoFind',
    'download.desc': '免费使用。首次浏览受保护目录需在系统设置中授予完全磁盘访问权限。',
    'download.btn': '下载 for macOS',
    'download.version': '版本 {version} · 需要 macOS {os}+',
    'download.note': '无账号、无追踪。构建产物：MeoFind.app',
    'shot.placeholder': '截图待补充',
    'footer.copy': 'MeoFind · macOS 文件工作台',
    'footer.plan': '网站方案文档',
  },
  en: {
    'nav.features': 'Features',
    'nav.preview': 'Preview',
    'nav.automation': 'Automation',
    'nav.trust': 'Tech',
    'nav.download': 'Download',
    'nav.downloadBtn': 'Download',
    'theme.toLight': 'Switch to light appearance',
    'theme.toDark': 'Switch to dark appearance',
    'hero.badge': 'Native macOS · Built with Swift',
    'hero.subtitle': 'Browse, preview, and automate scripts in one native window. Fewer apps, more flow.',
    'hero.cta.download': 'Download for macOS',
    'hero.cta.demo': 'Watch demo',
    'hero.meta.os': 'macOS 13+',
    'hero.meta.native': 'Swift native',
    'hero.meta.i18n': 'EN / 中文',
    'mock.preview': 'Live preview',
    'mock.output': '$ snippet done · Job #1',
    'mock.previewLabel': 'Preview',
    'mock.snippetsLabel': 'Snippets',
    'mock.outputLabel': 'Output',
    'story.eyebrow': 'Why MeoFind',
    'story.title': 'Three workflows, one window',
    'story.desc': 'From finding files to viewing content and running scripts—without juggling Finder, Preview, and Terminal.',
    'story.1.pain': 'Scrolling folders is slow',
    'story.1.title': 'Find',
    'story.1.text': 'Type to filter instantly; Tab cycles matches with live preview. Breadcrumbs and history keep navigation fluid.',
    'story.2.pain': 'Space preview falls short',
    'story.2.title': 'View',
    'story.2.text': 'Real-time preview for code, PDFs, images, and media—with toolbar actions, right in the browser.',
    'story.3.pain': 'Repetitive tasks from memory',
    'story.3.title': 'Act',
    'story.3.text': 'Snippets store scripts with auto-expanded variables; the output panel shows jobs and an interactive shell.',
    'features.eyebrow': 'Full picture',
    'features.title': 'Organized by how you work',
    'features.desc': 'From navigation to preview, automation, and remote access—productivity tools in a familiar file manager.',
    'feat.browse.title': 'Browse & navigate',
    'feat.browse.tag': 'Type to search, paths at a glance',
    'feat.browse.1': 'List and thumbnail views with adjustable icon size',
    'feat.browse.2': 'Breadcrumbs, path edit, back/forward, and history',
    'feat.browse.3': 'Drag-drop open, external windows, customizable blank double-click',
    'feat.sidebar.title': 'Sidebar',
    'feat.sidebar.tag': 'Favorites within reach',
    'feat.sidebar.1': 'Pin folders to favorites',
    'feat.sidebar.2': 'Devices show mounted disks and external drives',
    'feat.sidebar.3': 'Trash browsing, put back, and empty',
    'feat.preview.title': 'Rich preview',
    'feat.preview.tag': 'Select to view—no Space needed',
    'feat.preview.1': 'Syntax-highlighted text/code, Markdown/HTML modes',
    'feat.preview.2': 'Image zoom/rotate, PDF pages, audio/video playback',
    'feat.preview.3': 'Archive listing, spreadsheets, Quick Look fallback',
    'feat.previewBrowser.title': 'Preview browser',
    'feat.previewBrowser.tag': 'Filmstrip navigation',
    'feat.previewBrowser.1': 'Browse all files in the folder via bottom strip',
    'feat.previewBrowser.2': 'Prev/next item, detach preview window ⌘⌥P',
    'feat.previewBrowser.3': 'Custom preview rules per extension',
    'feat.snippets.title': 'Snippets',
    'feat.snippets.tag': 'Reusable command snippets',
    'feat.snippets.1': 'Shell, Python, AppleScript support',
    'feat.snippets.2': 'Auto-expand %p path, %d directory variables',
    'feat.snippets.3': 'Scope filters, JSON import/export',
    'feat.output.title': 'Output panel',
    'feat.output.tag': 'Scripts and shell together',
    'feat.output.1': 'One job tab per run, parallel tasks supported',
    'feat.output.2': 'Interactive zsh box synced with current directory',
    'feat.output.3': 'Streaming output, find, copy, and cancel',
    'feat.remote.title': 'Remote servers',
    'feat.remote.tag': 'FTP and more',
    'feat.remote.1': 'Connect and browse remote servers like local folders',
    'feat.remote.2': 'Recent servers for quick reconnect',
    'feat.remote.3': 'Works with favorites, preview, and Snippets',
    'feat.layout.title': 'Layout & efficiency',
    'feat.layout.tag': 'Shape the window to your flow',
    'feat.layout.1': 'Collapse and resize preview, Snippets, and output',
    'feat.layout.2': 'Window snap and multiple windows',
    'feat.layout.3': 'Custom toolbar with open-in-app buttons',
    'gallery.eyebrow': 'Screenshots',
    'gallery.title': 'Gallery & demos',
    'gallery.desc': 'Placeholders below—add assets to public/assets/ to replace.',
    'gallery.main': 'Three-column layout',
    'gallery.browse': 'List / thumbnails',
    'gallery.preview': 'Preview toolbar',
    'gallery.snippets': 'Snippets panel',
    'gallery.output': 'Output jobs',
    'gallery.remote': 'Remote connect',
    'video.eyebrow': 'Videos',
    'video.title': 'MeoFind in 60 seconds',
    'video.desc': 'Browse → preview → snippet → job output in one flow.',
    'video.main.title': 'Full workflow',
    'video.main.desc': 'Search → preview PDF → run snippet → view job',
    'video.main.placeholder': 'Video pending · demo-main.mp4',
    'video.preview.title': 'Preview highlights',
    'video.preview.desc': 'Code, images, PDF, and media at a glance',
    'video.preview.placeholder': 'Video pending · demo-preview.mp4',
    'workflow.eyebrow': 'One flow',
    'workflow.title': 'Five steps from select to execute',
    'workflow.1.title': 'Select file',
    'workflow.1.desc': 'In list or thumbnails',
    'workflow.2.title': 'Preview',
    'workflow.2.desc': 'Instant content view',
    'workflow.3.title': 'Run snippet',
    'workflow.3.desc': '⌘⇧S opens panel',
    'workflow.4.title': 'Job output',
    'workflow.4.desc': '⌘J shows results',
    'workflow.5.title': 'Continue',
    'workflow.5.desc': 'Shell or command box',
    'trust.eyebrow': 'Under the hood',
    'trust.title': 'Native, fast, trustworthy',
    'trust.1.title': 'Swift native',
    'trust.1.text': 'SwiftUI + AppKit, macOS 13+',
    'trust.2.title': 'Async loading',
    'trust.2.text': 'Background enumeration, thumbnail cache',
    'trust.3.title': 'Bilingual UI',
    'trust.3.text': 'Full English and Chinese support',
    'trust.4.title': 'Default viewer',
    'trust.4.text': 'Set as system folder viewer',
    'download.eyebrow': 'Get started',
    'download.title': 'Download MeoFind',
    'download.desc': 'Free to use. Full Disk Access may be required for protected folders.',
    'download.btn': 'Download for macOS',
    'download.version': 'Version {version} · requires macOS {os}+',
    'download.note': 'No account, no tracking. Build output: MeoFind.app',
    'shot.placeholder': 'Screenshot pending',
    'footer.copy': 'MeoFind · macOS file workstation',
    'footer.plan': 'Website plan',
  },
};

const featureNav = [
  { id: 'browse', key: 'feat.browse.title' },
  { id: 'sidebar', key: 'feat.sidebar.title' },
  { id: 'preview', key: 'feat.preview.title' },
  { id: 'preview-browser', key: 'feat.previewBrowser.title' },
  { id: 'snippets', key: 'feat.snippets.title' },
  { id: 'output', key: 'feat.output.title' },
  { id: 'remote', key: 'feat.remote.title' },
  { id: 'layout', key: 'feat.layout.title' },
];

let currentLang = localStorage.getItem(STORAGE_LANG) || 'zh';
let currentTheme = document.documentElement.dataset.theme || 'dark';
let versionInfo = { version: '1.0', minOS: '13.0', downloadUrl: '#download' };

function t(key, vars = {}) {
  const str = i18n[currentLang][key] ?? i18n.zh[key] ?? key;
  return Object.entries(vars).reduce((s, [k, v]) => s.replace(`{${k}}`, v), str);
}

function applyTheme() {
  document.documentElement.dataset.theme = currentTheme;
  const themeBtn = document.querySelector('.theme-toggle');
  if (themeBtn) {
    themeBtn.textContent = currentTheme === 'dark' ? '☀' : '🌙';
    themeBtn.setAttribute(
      'aria-label',
      t(currentTheme === 'dark' ? 'theme.toLight' : 'theme.toDark'),
    );
  }
}

function applyI18n() {
  document.documentElement.lang = currentLang === 'zh' ? 'zh-Hans' : 'en';
  document.querySelectorAll('[data-i18n]').forEach((el) => {
    const key = el.getAttribute('data-i18n');
    el.textContent = t(key);
  });
  const langBtn = document.querySelector('.lang-toggle');
  if (langBtn) langBtn.textContent = currentLang === 'zh' ? 'EN' : '中文';
  applyTheme();
  updateVersionDisplay();
}

function updateVersionDisplay() {
  const el = document.querySelector('[data-version-text]');
  if (el) {
    el.textContent = t('download.version', {
      version: versionInfo.version,
      os: versionInfo.minOS,
    });
  }
  document.querySelectorAll('[data-download-link]').forEach((a) => {
    a.href = versionInfo.downloadUrl;
  });
}

async function loadVersion() {
  try {
    const res = await fetch('/version.json');
    if (res.ok) {
      versionInfo = { ...versionInfo, ...await res.json() };
      updateVersionDisplay();
    }
  } catch {
    /* static fallback */
  }
}

function setupThemeToggle() {
  document.querySelector('.theme-toggle')?.addEventListener('click', () => {
    currentTheme = currentTheme === 'dark' ? 'light' : 'dark';
    localStorage.setItem(STORAGE_THEME, currentTheme);
    applyTheme();
  });
}

function setupLangToggle() {
  document.querySelector('.lang-toggle')?.addEventListener('click', () => {
    currentLang = currentLang === 'zh' ? 'en' : 'zh';
    localStorage.setItem(STORAGE_LANG, currentLang);
    applyI18n();
  });
}

function setupReveal() {
  const els = document.querySelectorAll('.reveal');
  if (!window.IntersectionObserver) {
    els.forEach((el) => el.classList.add('is-visible'));
    return;
  }
  const io = new IntersectionObserver(
    (entries) => {
      entries.forEach((entry) => {
        if (entry.isIntersecting) {
          entry.target.classList.add('is-visible');
          io.unobserve(entry.target);
        }
      });
    },
    { threshold: 0.12, rootMargin: '0px 0px -40px 0px' },
  );
  els.forEach((el) => io.observe(el));
}

function setupNavHighlight() {
  const sections = [
    { id: 'story', nav: 'nav.features' },
    { id: 'features', nav: 'nav.features' },
    { id: 'gallery', nav: 'nav.preview' },
    { id: 'workflow', nav: 'nav.automation' },
    { id: 'trust', nav: 'nav.trust' },
    { id: 'download', nav: 'nav.download' },
  ];

  const navLinks = document.querySelectorAll('.site-nav__links a[data-nav]');
  const featureLinks = document.querySelectorAll('.features-nav a');

  function setActive(links, activeHref) {
    links.forEach((a) => {
      a.classList.toggle('is-active', a.getAttribute('href') === activeHref);
    });
  }

  const observer = new IntersectionObserver(
    (entries) => {
      const visible = entries
        .filter((e) => e.isIntersecting)
        .sort((a, b) => b.intersectionRatio - a.intersectionRatio)[0];
      if (!visible) return;
      const id = visible.target.id;
      const section = sections.find((s) => s.id === id);
      if (section) {
        setActive(navLinks, `#${id}`);
      }
      if (id.startsWith('feat-') || featureNav.some((f) => f.id === id)) {
        const featId = id.startsWith('feat-') ? id.replace('feat-', '') : id;
        setActive(featureLinks, `#${featId}`);
      }
    },
    { rootMargin: '-40% 0px -45% 0px', threshold: 0 },
  );

  sections.forEach((s) => {
    const el = document.getElementById(s.id);
    if (el) observer.observe(el);
  });
  featureNav.forEach((f) => {
    const el = document.getElementById(f.id);
    if (el) observer.observe(el);
  });
}

function setupWorkflowSteps() {
  const steps = document.querySelectorAll('.workflow__step');
  const section = document.getElementById('workflow');
  if (!section || !steps.length) return;

  const activate = (index) => {
    steps.forEach((step, i) => {
      step.classList.toggle('is-active', i <= index);
    });
  };

  if (!window.IntersectionObserver) {
    activate(steps.length - 1);
    return;
  }

  const io = new IntersectionObserver(
    (entries) => {
      entries.forEach((entry) => {
        if (entry.isIntersecting) {
          let tick = 0;
          const interval = setInterval(() => {
            activate(tick);
            tick += 1;
            if (tick >= steps.length) clearInterval(interval);
          }, 400);
        }
      });
    },
    { threshold: 0.3 },
  );
  io.observe(section);
}

function setupHeroSearchDemo() {
  const rows = document.querySelectorAll('.mock-row[data-file]');
  const input = document.querySelector('.mock-search__input');
  if (!rows.length || !input) return;

  const files = ['readme.md', 'package.json', 'src/', 'assets/', 'docs/'];
  let charIndex = 0;
  const query = 'readme';

  function tick() {
    if (charIndex <= query.length) {
      input.textContent = query.slice(0, charIndex);
      const q = query.slice(0, charIndex).toLowerCase();
      rows.forEach((row) => {
        const file = row.getAttribute('data-file') || '';
        const match = !q || file.includes(q);
        row.classList.toggle('mock-row--hidden', !match);
        row.classList.toggle('mock-row--highlight', match && file.startsWith(q));
      });
      charIndex += 1;
      setTimeout(tick, charIndex <= query.length ? 280 : 2200);
    } else {
      charIndex = 0;
      setTimeout(tick, 800);
    }
  }
  tick();
}

function setupScreenshotFallbacks() {
  document.querySelectorAll('[data-shot]').forEach((container) => {
    const name = container.getAttribute('data-shot');
    const img = container.querySelector('img');
    if (!img) return;
    img.addEventListener('error', () => {
      img.style.display = 'none';
      const ph = container.querySelector('.feature-shot__placeholder');
      if (ph) ph.style.display = 'flex';
    });
    img.src = `/assets/screenshots/${name}`;
  });
}

applyI18n();
setupThemeToggle();
setupLangToggle();
setupReveal();
setupNavHighlight();
setupWorkflowSteps();
setupHeroSearchDemo();
setupScreenshotFallbacks();
loadVersion();
