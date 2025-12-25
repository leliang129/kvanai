import { themes as prismThemes } from "prism-react-renderer";
import type { Config } from "@docusaurus/types";
import type * as Preset from "@docusaurus/preset-classic";

// This runs in Node.js - Don't use client-side code here (browser APIs, JSX...)

const config: Config = {
  title: "OpsTrack",
  tagline: "记录运维工程师的集群巡检、可观测与自动化实践",
  favicon: "img/favicon.ico",

  // Future flags, see https://docusaurus.io/docs/api/docusaurus-config#future
  future: {
    v4: true, // Improve compatibility with the upcoming Docusaurus v4
  },

  // Set the production url of your site here
  url: "https://ops-track.example.com",
  // Set the /<baseUrl>/ pathname under which your site is served
  // For GitHub pages deployment, it is often '/<projectName>/'
  baseUrl: "/",

  // GitHub pages deployment config.
  // If you aren't using GitHub pages, you don't need these.
  organizationName: "ops-labs", // Usually your GitHub org/user name.
  projectName: "ops-website", // Usually your repo name.

  onBrokenLinks: "throw",

  // Even if you don't use internationalization, you can use this field to set
  // useful metadata like html lang. For example, if your site is Chinese, you
  // may want to replace "en" with "zh-Hans".
  i18n: {
    defaultLocale: "zh-Hans",
    locales: ["zh-Hans"],
  },

  presets: [
    [
      "classic",
      {
        docs: {
          path: "docs/kb",
          sidebarPath: "./sidebars.ts",
          // Please change this to your repo.
          // Remove this to remove the "edit this page" links.
          editUrl: "https://github.com/ops-labs/ops-website/tree/main/",
        },
        blog: {
          showReadingTime: true,
          feedOptions: {
            type: ["rss", "atom"],
            xslt: true,
          },
          // Please change this to your repo.
          // Remove this to remove the "edit this page" links.
          editUrl: "https://github.com/ops-labs/ops-website/tree/main/",
          // Useful options to enforce blogging best practices
          onInlineTags: "warn",
          onInlineAuthors: "warn",
          onUntruncatedBlogPosts: "warn",
        },
        theme: {
          customCss: "./src/css/custom.css",
        },
      } satisfies Preset.Options,
    ],
  ],

  plugins: [
    [
      "@docusaurus/plugin-content-docs",
      {
        id: "ops",
        path: "docs/ops",
        routeBasePath: "ops",
        sidebarPath: "./sidebars.ops.ts",
        editUrl: "https://github.com/ops-labs/ops-website/tree/main/",
      },
    ],
  ],

  themeConfig: {
    // Replace with your project's social card
    image: "img/docusaurus-social-card.jpg",
    colorMode: {
      respectPrefersColorScheme: true,
    },
    navbar: {
      title: "OPS NOTES",
      logo: {
        alt: "OpsTrack Logo",
        src: "img/logo.svg",
      },
      items: [
        {
          type: "docSidebar",
          sidebarId: "opsSidebar",
          position: "left",
          label: "知识库",
        },
        {
          type: "dropdown",
          label: "运维",
          position: "left",
          items: [
            {
              type: "docSidebar",
              docsPluginId: "ops",
              sidebarId: "dockerSidebar",
              label: "Docker",
            },
            {
              type: "docSidebar",
              docsPluginId: "ops",
              sidebarId: "devopsSidebar",
              label: "DevOps",
            },
            {
              type: "docSidebar",
              docsPluginId: "ops",
              sidebarId: "databaseSidebar",
              label: "Database",
            },
            {
              type: "docSidebar",
              docsPluginId: "ops",
              sidebarId: "kubernetesSidebar",
              label: "Kubernetes",
            },
            {
              type: "docSidebar",
              docsPluginId: "ops",
              sidebarId: "prometheusSidebar",
              label: "Prometheus",
            },
          ],
        },
        {
          type: "dropdown",
          label: "脚本",
          position: "left",
          items: [
            {
              type: "docSidebar",
              docsPluginId: "ops",
              sidebarId: "shellSidebar",
              label: "Shell概览",
            },
            {
              type: "docSidebar",
              docsPluginId: "ops",
              sidebarId: "pythonSidebar",
              label: "Python概览",
            },
          ],
        },
        {
          type: "docSidebar",
          sidebarId: "journalSidebar",
          label: "工作日志",
          position: "left",
        },
        // { to: "/about", label: "关于", position: "left" },
        { to: "/nav", label: "常用网站", position: "right" },
        // {
        //   to: "https://github.com/ops-labs/ops-website",
        //   label: "GitHub",
        //   position: "right",
        // },
      ],
    },
    footer: {
      style: "dark",
      links: [
        {
          title: "知识库",
          items: [
            {
              label: "指南概览",
              to: "/docs/intro",
            },
            {
              label: "巡检手册",
              to: "/docs/platform/kubernetes",
            },
          ],
        },
        {
          title: "工具 & 社区",
          items: [
            {
              label: "CNCF",
              href: "https://www.cncf.io/",
            },
            {
              label: "Prometheus Docs",
              href: "https://prometheus.io/docs/",
            },
            {
              label: "Kubernetes Docs",
              href: "https://kubernetes.io/docs/",
            },
          ],
        },
        {
          title: "更多",
          items: [
            {
              label: "工作日志",
              to: "/docs/journal",
            },
            {
              label: "GitHub",
              href: "https://github.com/ops-labs/ops-website",
            },
          ],
        },
      ],
      copyright: `版权所有 © ${new Date().getFullYear()} OpsTrack · 运维工程师日志`,
    },
    prism: {
      theme: prismThemes.github,
      darkTheme: prismThemes.dracula,
      additionalLanguages: ["bash", "powershell", "python", "sql"],
    },
  } satisfies Preset.ThemeConfig,
};

export default config;
