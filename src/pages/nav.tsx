import type { ReactNode } from "react";
import { useEffect, useMemo, useRef, useState } from "react";
import clsx from "clsx";
import Layout from "@theme/Layout";

import styles from "./nav.module.css";

const STORAGE_KEY = "nav-home-data";
const STORAGE_VERSION_KEY = "nav-home-data-version";
const DATA_VERSION = "2025-11-devops-v1";

type Site = {
  id: string;
  name: string;
  description: string;
  tags?: string[];
  shortcut?: string;
  url: string;
  emoji?: string;
};

type Category = {
  id: string;
  label: string;
  emoji?: string;
  description?: string;
  accent?: string;
  sites: Site[];
};

type SiteWithCategory = Site & {
  categoryId: string;
  categoryLabel: string;
  categoryEmoji?: string;
};

const presetCategories: Category[] = [
  {
    id: "mirrors",
    label: "软件源",
    emoji: "🛰️",
    description: "高校镜像、包仓库与加速节点",
    accent: "from-brand/20 to-transparent",
    sites: [
      {
        id: "mirror-tuna",
        name: "清华源",
        description: "TUNA 协会维护的开源镜像站",
        tags: ["软件源", "清华大学", "镜像站"],
        shortcut: "Shift+1",
        url: "https://mirrors.tuna.tsinghua.edu.cn/",
        emoji: "🏫",
      },
      {
        id: "mirror-aliyun",
        name: "阿里源",
        description: "阿里云官方镜像服务",
        tags: ["软件源", "阿里巴巴", "镜像站"],
        shortcut: "Shift+2",
        url: "https://mirrors.aliyun.com/",
        emoji: "🛒",
      },
      {
        id: "mirror-huawei",
        name: "华为源",
        description: "华为云镜像中心",
        tags: ["软件源", "华为", "镜像站"],
        shortcut: "Shift+3",
        url: "https://mirrors.huaweicloud.com/",
        emoji: "🚀",
      },
      {
        id: "maven-central",
        name: "Maven 中央仓库",
        description: "官方依赖搜索与下载",
        tags: ["Maven", "Repository", "Central"],
        shortcut: "Shift+4",
        url: "https://mvnrepository.com/",
        emoji: "📦",
      },
      {
        id: "maven-aliyun",
        name: "Maven 阿里仓库",
        description: "阿里云提供的 Maven 镜像",
        tags: ["Maven", "Repository", "阿里云"],
        shortcut: "Shift+5",
        url: "https://maven.aliyun.com/mvn/guide",
        emoji: "🧭",
      },
      {
        id: "npm-taobao",
        name: "NPM 淘宝源",
        description: "npmmirror 官方站点",
        tags: ["Package Manager", "Node.js", "npm"],
        shortcut: "Shift+6",
        url: "https://npmmirror.com/",
        emoji: "📦",
      },
    ],
  },
  {
    id: "containers",
    label: "虚拟化",
    emoji: "🐳",
    description: "Docker / K8s 及边缘工具",
    accent: "from-accent/30 to-transparent",
    sites: [
      {
        id: "dockerfile-ref",
        name: "Dockerfile 参考文档",
        description: "Deepzz 维护的中文指南",
        tags: ["Docker", "Container", "镜像构建"],
        shortcut: "Ctrl+1",
        url: "https://deepzz.com/post/dockerfile-reference.html",
        emoji: "📘",
      },
      {
        id: "composerize",
        name: "DockerCompose 生成",
        description: "一键把 CLI 转成 Compose",
        tags: ["docker", "compose", "多容器应用"],
        shortcut: "Ctrl+2",
        url: "https://www.composerize.com/",
        emoji: "🧩",
      },
      {
        id: "k3s-docs",
        name: "K3s",
        description: "轻量级 K8s 中文文档",
        tags: ["k3s", "kubernetes", "轻量级"],
        shortcut: "Ctrl+3",
        url: "https://docs.k3s.io/zh/",
        emoji: "🌱",
      },
      {
        id: "kind",
        name: "Kind",
        description: "本地 Docker 上跑 K8s",
        tags: ["kubernetes", "docker", "本地开发"],
        shortcut: "Ctrl+4",
        url: "https://kind.sigs.k8s.io/",
        emoji: "🧪",
      },
      {
        id: "k8s-api",
        name: "K8s API 文档",
        description: "官方 API 参考",
        tags: ["kubernetes", "API", "文档"],
        shortcut: "Ctrl+5",
        url: "https://kubernetes.io/docs/reference/kubernetes-api/",
        emoji: "📚",
      },
      {
        id: "artifact-hub",
        name: "Helm 仓库",
        description: "Artifact Hub chart 搜索",
        tags: ["kubernetes", "helm", "charts"],
        shortcut: "Ctrl+6",
        url: "https://artifacthub.io/",
        emoji: "🎯",
      },
      {
        id: "helm-docs",
        name: "Helm 文档",
        description: "Helm 官方站",
        tags: ["kubernetes", "helm", "包管理"],
        shortcut: "Ctrl+7",
        url: "https://helm.sh/",
        emoji: "📖",
      },
      {
        id: "registry-explorer",
        name: "Registry Explorer",
        description: "可视化查看镜像层",
        tags: ["kubernetes", "docker", "镜像分析"],
        shortcut: "Ctrl+8",
        url: "https://explore.ggcr.dev/",
        emoji: "🔍",
      },
      {
        id: "dodo-sync",
        name: "渡渡鸟镜像同步",
        description: "国内 Docker 镜像加速",
        tags: ["docker", "镜像同步", "加速"],
        shortcut: "Ctrl+9",
        url: "https://docker.aityp.com/",
        emoji: "⚡",
      },
    ],
  },
  {
    id: "toolkit",
    label: "工具箱",
    emoji: "🧰",
    description: "常用可视化与效率小工具",
    accent: "from-emerald-400/20 to-transparent",
    sites: [
      {
        id: "ctool",
        name: "常用工具合集",
        description: "开发 & 生活小工具集合",
        tags: ["开发工具", "在线工具", "实用工具"],
        shortcut: "Alt+1",
        url: "https://ctool.dev/",
        emoji: "🧮",
      },
      {
        id: "crontab",
        name: "Crontab 可视化",
        description: "生成 Cron 表达式",
        tags: ["crontab", "定时任务", "可视化"],
        shortcut: "Alt+2",
        url: "https://crontab-generator.org/",
        emoji: "⏰",
      },
      {
        id: "reference",
        name: "快速参考备忘录",
        description: "常用命令速查",
        tags: ["备忘录", "参考手册", "开发文档"],
        shortcut: "Alt+3",
        url: "https://wangchujiang.com/reference/",
        emoji: "📒",
      },
      {
        id: "todo",
        name: "在线待办清单",
        description: "极简网页 ToDo",
        tags: ["待办清单", "任务管理", "生产力工具"],
        shortcut: "Alt+4",
        url: "https://www.ricocc.com/todo/",
        emoji: "✅",
      },
      {
        id: "ip-test",
        name: "IP 测试工具",
        description: "多节点 Ping / Trace",
        tags: ["网络测试", "IP诊断", "网络工具"],
        shortcut: "Alt+5",
        url: "https://ping.sx/ping",
        emoji: "🌐",
      },
      {
        id: "excalidraw",
        name: "Excalidraw",
        description: "多人实时白板",
        tags: ["白板", "绘图工具", "协作"],
        shortcut: "Alt+6",
        url: "https://excalidraw.com/",
        emoji: "🖊️",
      },
      {
        id: "openjdk",
        name: "OpenJDK 镜像",
        description: "Eclipse Adoptium 中文站",
        tags: ["Java", "OpenJDK", "Eclipse"],
        shortcut: "Alt+7",
        url: "https://adoptium.net/zh-CN/",
        emoji: "☕",
      },
      {
        id: "jdk-store",
        name: "JDK 下载站",
        description: "快速下载多版本 JDK",
        tags: ["Java", "JDK", "下载"],
        shortcut: "Alt+8",
        url: "https://www.injdk.cn/",
        emoji: "📥",
      },
      {
        id: "openjdk-tuna",
        name: "OpenJDK 镜像站",
        description: "Adoptium 清华镜像",
        tags: ["Java", "OpenJDK", "镜像站"],
        shortcut: "Alt+9",
        url: "https://mirrors.tuna.tsinghua.edu.cn/Adoptium/",
        emoji: "🏛️",
      },
      {
        id: "curl-converter",
        name: "Curl 转换工具",
        description: "curl 命令转多语言",
        tags: ["curl", "HTTP", "代码生成"],
        shortcut: "Alt+0",
        url: "https://curlconverter.com/",
        emoji: "🧠",
      },
      {
        id: "temp-mail",
        name: "临时邮箱",
        description: "TempMail Plus",
        tags: ["临时邮箱", "隐私保护", "测试工具"],
        shortcut: "Alt+Shift+6",
        url: "https://tempmail.plus/zh/#!",
        emoji: "📮",
      },
      {
        id: "email-once",
        name: "Email Once",
        description: "一次性邮箱",
        tags: ["临时邮箱", "一次性邮箱", "测试工具"],
        shortcut: "Alt+Shift+7",
        url: "https://email-once.com/",
        emoji: "✉️",
      },
    ],
  },
  {
    id: "ai-hub",
    label: "AI集",
    emoji: "🤖",
    description: "AI 设计、自动化与智能体平台",
    accent: "from-fuchsia-400/30 to-transparent",
    sites: [
      {
        id: "lovart",
        name: "LOVART 设计",
        description: "AI 设计与素材合集",
        tags: ["AI", "工具", "合集"],
        shortcut: "Alt+Shift+1",
        url: "https://www.lovart.ai/",
        emoji: "🎨",
      },
      {
        id: "fastgpt",
        name: "FastGPT",
        description: "企业级问答与知识库",
        tags: ["AI", "工具", "知识库"],
        shortcut: "Alt+Shift+2",
        url: "https://fastgpt.io/zh",
        emoji: "⚙️",
      },
      {
        id: "n8n",
        name: "n8n",
        description: "开源自动化工作流",
        tags: ["AI", "工具", "自动化"],
        shortcut: "Alt+Shift+3",
        url: "https://github.com/n8n-io/n8n",
        emoji: "🔗",
      },
      {
        id: "dify",
        name: "Dify",
        description: "多模态智能体平台",
        tags: ["AI", "工具", "智能体"],
        shortcut: "Alt+Shift+4",
        url: "https://docs.dify.ai/zh-hans/introduction",
        emoji: "🪄",
      },
      {
        id: "chatgpt-aihub",
        name: "ChatGPT",
        description: "OpenAI 官方入口",
        tags: ["AI", "对话", "OpenAI"],
        shortcut: "Alt+Shift+5",
        url: "https://chatgpt.com/",
        emoji: "💬",
      },
      {
        id: "gemini",
        name: "Google Gemini",
        description: "Google 最新生成式模型",
        tags: ["AI", "Google", "多模态"],
        shortcut: "Alt+Shift+6",
        url: "https://gemini.google.com/",
        emoji: "🌌",
      },
    ],
  },
];

const quickSuggestions = [
  { id: "mirrors", label: "软件源", keyword: "软件源" },
  { id: "containers", label: "容器工具", keyword: "容器" },
  { id: "toolkit", label: "效率工具", keyword: "工具" },
  { id: "ai-hub", label: "AI 工具", keyword: "AI" },
];

function cloneCategories(list: Category[]): Category[] {
  return list.map((category) => ({
    ...category,
    sites: category.sites.map((site) => ({ ...site })),
  }));
}

function persistLocalCategories(data: Category[]) {
  if (typeof window === "undefined") return;
  try {
    window.localStorage.setItem(STORAGE_KEY, JSON.stringify(data));
    window.localStorage.setItem(STORAGE_VERSION_KEY, DATA_VERSION);
  } catch (error) {
    console.warn("Failed to persist categories", error);
  }
}

function seedPresetCategories(): Category[] {
  const data = cloneCategories(presetCategories);
  persistLocalCategories(data);
  return data;
}

function loadInitialCategories(): Category[] {
  if (typeof window === "undefined") return cloneCategories(presetCategories);
  const cachedVersion = window.localStorage.getItem(STORAGE_VERSION_KEY);
  const cached = window.localStorage.getItem(STORAGE_KEY);
  if (!cached || cachedVersion !== DATA_VERSION) {
    return seedPresetCategories();
  }
  try {
    const parsed = JSON.parse(cached) as unknown;
    if (!Array.isArray(parsed)) return seedPresetCategories();
    const merged = cloneCategories(parsed as Category[]);
    persistLocalCategories(merged);
    return merged;
  } catch (error) {
    console.warn("Failed to parse cached categories", error);
    return seedPresetCategories();
  }
}

export default function Nav(): ReactNode {
  return (
    <Layout title="导航" description="运维常用站点与工具导航">
      <NavContent />
    </Layout>
  );
}

function NavContent(): ReactNode {
  const [categories, setCategories] = useState<Category[]>(loadInitialCategories);
  const [activeCategory, setActiveCategory] = useState<string>(
    presetCategories[0]?.id ?? "mirrors",
  );
  const [searchTerm, setSearchTerm] = useState("");
  const [isSearchOpen, setIsSearchOpen] = useState(false);
  const searchInputRef = useRef<HTMLInputElement | null>(null);

  useEffect(() => {
    if (!isSearchOpen) return;
    const input = searchInputRef.current;
    if (!input) return;
    input.focus();
  }, [isSearchOpen]);

  useEffect(() => {
    const handleKeyDown = (event: KeyboardEvent) => {
      if (event.key === "Escape") {
        setIsSearchOpen(false);
        return;
      }
      const key = event.key.toLowerCase();
      const isMeta = event.metaKey || event.ctrlKey;
      if (isMeta && key === "k") {
        event.preventDefault();
        setIsSearchOpen(true);
      }
    };
    if (typeof window === "undefined") return;
    window.addEventListener("keydown", handleKeyDown);
    return () => window.removeEventListener("keydown", handleKeyDown);
  }, []);

  useEffect(() => {
    persistLocalCategories(categories);
  }, [categories]);

  const allSites = useMemo<SiteWithCategory[]>(
    () =>
      categories.flatMap((category) =>
        category.sites.map((site) => ({
          ...site,
          categoryId: category.id,
          categoryLabel: category.label,
          categoryEmoji: category.emoji,
        })),
      ),
    [categories],
  );

  const displayedSites = useMemo<SiteWithCategory[]>(() => {
    const term = searchTerm.trim().toLowerCase();
    if (!term) {
      const category = categories.find((item) => item.id === activeCategory);
      return (category?.sites ?? []).map((site) => ({
        ...site,
        categoryId: category?.id ?? "",
        categoryLabel: category?.label ?? "",
        categoryEmoji: category?.emoji,
      }));
    }
    return allSites.filter((site) => {
      const haystack = `${site.name} ${site.description}`.toLowerCase();
      const tagMatch = site.tags?.some((tag) => tag.toLowerCase().includes(term));
      return haystack.includes(term) || Boolean(tagMatch);
    });
  }, [searchTerm, activeCategory, categories, allSites]);

  const activeCategoryMeta = categories.find(
    (category) => category.id === activeCategory,
  );

  return (
    <main className={styles.page}>
      <div className={styles.container}>
        <div className={styles.headerRow}>
          <div className={styles.terminalHeader}>
            <div className={styles.terminalButtons} aria-hidden="true">
              <span />
              <span />
              <span />
            </div>
            <span className={styles.terminalTitle}>kvanni@notes ~/nav</span>
            <span className={styles.headerBadge}>READY</span>
          </div>
        </div>

        <section className={styles.panel} aria-label="分类">
          <div className={styles.panelHeading}>
            <p className={styles.kicker}>CATEGORY</p>
            <div className={styles.panelMeta}>
              <span>{categories.length} 分类</span>
              <span>·</span>
              <span>{allSites.length} 站点</span>
              <span>·</span>
              <button
                type="button"
                className={styles.inlineLink}
                onClick={() => {
                  setSearchTerm("");
                  setIsSearchOpen(true);
                }}
              >
                搜索
              </button>
            </div>
          </div>

          <div className={styles.categoryGrid}>
            {categories.map((category) => {
              const isActive = category.id === activeCategory && !searchTerm;
              return (
                <button
                  key={category.id}
                  type="button"
                  className={clsx(styles.categoryCard, isActive && styles.active)}
                  onClick={() => {
                    setActiveCategory(category.id);
                    setSearchTerm("");
                  }}
                >
                  <span className={styles.categoryEmoji} aria-hidden="true">
                    {category.emoji ?? "🔖"}
                  </span>
                  <span className={styles.categoryLabel}>{category.label}</span>
                  <span className={styles.categoryDesc}>
                    {category.description ?? ""}
                  </span>
                </button>
              );
            })}
          </div>
        </section>

        <section className={styles.panel} aria-label="站点">
          <div className={styles.panelHeading}>
            <div>
              <p className={styles.kicker}>{searchTerm ? "SEARCH" : "FEATURED"}</p>
              <h1 className={styles.h1}>
                {searchTerm
                  ? `匹配到 ${displayedSites.length} 个站点`
                  : `${activeCategoryMeta?.emoji ?? ""} ${activeCategoryMeta?.label ?? ""}`}
              </h1>
            </div>
            {!searchTerm ? (
              <p className={styles.muted}>点击卡片在新标签页打开</p>
            ) : null}
          </div>

          {displayedSites.length === 0 ? (
            <div className={styles.emptyState}>没找到站点，换个关键词或切换分类。</div>
          ) : (
            <div className={styles.siteGrid}>
              {displayedSites.map((site) => (
                <a
                  key={`${site.categoryId}:${site.id}`}
                  href={site.url}
                  target="_blank"
                  rel="noreferrer"
                  className={styles.siteCard}
                >
                  <div className={styles.siteHeader}>
                    <div className={styles.siteTitleRow}>
                      <span className={styles.siteEmoji} aria-hidden="true">
                        {site.emoji ?? "🔗"}
                      </span>
                      <div>
                        <p className={styles.siteName}>{site.name}</p>
                        <p className={styles.siteDesc}>{site.description}</p>
                      </div>
                    </div>
                  </div>
                  {site.tags?.length ? (
                    <div className={styles.tagRow}>
                      {site.tags.slice(0, 6).map((tag) => (
                        <span key={tag} className={styles.tag}>
                          #{tag}
                        </span>
                      ))}
                    </div>
                  ) : null}
                  {searchTerm ? (
                    <p className={styles.siteFootnote}>
                      {site.categoryEmoji} {site.categoryLabel}
                    </p>
                  ) : null}
                </a>
              ))}
            </div>
          )}
        </section>
      </div>

      {isSearchOpen ? (
        <div
          className={styles.modalOverlay}
          role="dialog"
          aria-modal="true"
          aria-label="全局搜索"
          onClick={(event) => {
            if (event.target === event.currentTarget) setIsSearchOpen(false);
          }}
        >
          <div className={styles.modalCard}>
            <div className={styles.modalHeader}>
              <div>
                <p className={styles.kicker}>SEARCH</p>
                <p className={styles.modalTitle}>全局搜索</p>
                <p className={styles.muted}>输入关键词实时过滤，回车可直接打开</p>
              </div>
              <button
                type="button"
                className={styles.modalClose}
                onClick={() => setIsSearchOpen(false)}
              >
                关闭
              </button>
            </div>
            <div className={styles.modalBody}>
              <div className={styles.searchBar}>
                <span className={styles.searchIcon} aria-hidden="true">
                  🔍
                </span>
                <label className={styles.srOnly} htmlFor="nav-search">
                  搜索站点
                </label>
                <input
                  id="nav-search"
                  ref={searchInputRef}
                  type="search"
                  value={searchTerm}
                  onChange={(event) => setSearchTerm(event.target.value)}
                  onKeyDown={(event) => {
                    if (event.key !== "Enter") return;
                    const first = displayedSites[0];
                    if (!first || typeof window === "undefined") return;
                    window.open(first.url, "_blank", "noopener,noreferrer");
                    setIsSearchOpen(false);
                  }}
                  placeholder="搜索镜像站、K8s、AI 工具..."
                  className={styles.searchInput}
                />
              </div>

              <div className={styles.suggestRow}>
                <span className={styles.suggestLabel}>快捷筛选</span>
                {quickSuggestions.map((item) => (
                  <button
                    type="button"
                    key={item.id}
                    className={styles.suggestChip}
                    onClick={() => setSearchTerm(item.keyword)}
                  >
                    #{item.label}
                  </button>
                ))}
                {searchTerm ? (
                  <button
                    type="button"
                    className={styles.inlineLink}
                    onClick={() => setSearchTerm("")}
                  >
                    清空
                  </button>
                ) : null}
              </div>

              <div className={styles.resultMeta}>
                {searchTerm
                  ? `匹配到 ${displayedSites.length} 个站点`
                  : "输入关键词开始搜索"}
              </div>

              <div className={styles.resultList} role="list">
                {displayedSites.length === 0 ? (
                  <p className={styles.emptyList}>暂无匹配结果。</p>
                ) : (
                  displayedSites.map((site) => (
                    <a
                      key={`modal:${site.categoryId}:${site.id}`}
                      href={site.url}
                      target="_blank"
                      rel="noreferrer"
                      className={styles.resultItem}
                      onClick={() => setIsSearchOpen(false)}
                    >
                      <span className={styles.resultEmoji} aria-hidden="true">
                        {site.emoji ?? "🔗"}
                      </span>
                      <span className={styles.resultMain}>
                        <span className={styles.resultName}>{site.name}</span>
                        <span className={styles.resultDesc}>{site.description}</span>
                      </span>
                      <span className={styles.resultSide}>
                        <span className={styles.resultCategory}>
                          {site.categoryEmoji} {site.categoryLabel}
                        </span>
                      </span>
                    </a>
                  ))
                )}
              </div>
            </div>
          </div>
        </div>
      ) : null}
    </main>
  );
}
