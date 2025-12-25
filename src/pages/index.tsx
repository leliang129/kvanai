import type { ReactNode } from "react";
import clsx from "clsx";
import Link from "@docusaurus/Link";
import useDocusaurusContext from "@docusaurus/useDocusaurusContext";
import Layout from "@theme/Layout";
import Heading from "@theme/Heading";
import HomepageFeatures from "@site/src/components/HomepageFeatures";

import styles from "./index.module.css";

const consoleCommands = [
  {
    command: "runbook sync --today",
    result: "4 条巡检记录待归档",
  },
  {
    command: "ops health k8s-prod",
    result: "APIServer ok · p95 140ms · pending pods 0",
  },
  {
    command: "gitops plan",
    result: "2 条流水线等待审批",
  },
];

const consoleSummary = [
  { label: "今日巡检", value: "4 集群" },
  { label: "告警复盘", value: "3 事件" },
  { label: "自动化任务", value: "5 流水线" },
];

const clusterHealth = [
  { label: "Nodes Ready", value: "24/24" },
  { label: "Pending Pods", value: "0" },
  { label: "API Latency p99", value: "120ms" },
];

const monitorStatus = [
  { label: "TSDB", value: "81% disk" },
  { label: "Rules", value: "642 OK" },
  { label: "Remote Write", value: "stable" },
];

const incidentQuickstart = [
  "先缩小爆炸半径：kubectl -n <ns> get deploy,po -o wide",
  '观测关键路径：CPU / GC / 5xx / latency，sum(rate(http_requests_total{status=~"5.."}))',
  "有回滚就先回滚：kubectl -n <ns> rollout undo deploy/<name>",
];

const domainNotes = [
  {
    title: "Kubernetes",
    meta: "deploy / diagnose / rollback",
    description: "以「故障→复盘→runbook」方式沉淀集群与业务的关键路径。",
    link: "/docs/platform/kubernetes",
    icon: "K8",
  },
  {
    title: "Prometheus",
    meta: "metrics / alerts / promql",
    description: "告警不止“响”，还要可执行：分层、抑制、可观测闭环。",
    link: "/docs/observability/prometheus",
    icon: "PM",
  },
  {
    title: "DevOps",
    meta: "ci/cd / release / postmortem",
    description: "把发布当作流水线：可追溯、可回滚、可量化、可复盘。",
    link: "/docs/automation/devops",
    icon: "DO",
  },
  {
    title: "Shell",
    meta: "one-liners / net / logs",
    description: "现场最有用的工具箱：切片日志、提炼关键信息、定位瓶颈。",
    link: "/docs/automation/shell/intro",
    icon: "SH",
  },
  {
    title: "Python",
    meta: "automation / api / parsing",
    description: "脚本工程化：重试、并发、可配置与测试，支撑长期维护。",
    link: "/docs/automation/python/intro",
    icon: "PY",
  },
  {
    title: "Database",
    meta: "mysql / postgres / redis",
    description: "备份恢复、性能调优与高可用策略，保障核心数据稳定。",
    link: "/docs/data/database",
    icon: "DB",
  },
  {
    title: "Docker",
    meta: "registry / build / runtime",
    description: "镜像管理、构建优化与运行时安全，为集群基础设施打底。",
    link: "/docs/automation/devops",
    icon: "DK",
  },
  {
    title: "AI Ops",
    meta: "llm / agent / anomaly",
    description: "引入 AI 助手与异常检测，加速 Runbook 生成与告警分析。",
    link: "/docs/automation/devops",
    icon: "AI",
  },
];

function HomepageHeader(): ReactNode {
  const { siteConfig } = useDocusaurusContext();
  return (
    <header className={clsx("hero", styles.heroBanner)}>
      <div className="container">
        <div className={styles.heroGrid}>
          <div>
            <p className={styles.heroPrompt}>
              <span className={styles.heroPromptUser}>kvanni@notes</span> ~/home %
            </p>
            <Heading as="h1" className={styles.heroHeadline}>
              {siteConfig.title.toLowerCase()}
              <span className={styles.heroHeadlineAccent}>.runbooks</span>
            </Heading>
            <pre className={styles.heroCodeBlock}>
              <code>
                <span className={styles.heroCodeComment}>
                  {"// "}
                  {siteConfig.tagline}
                </span>
                {"\n"}
                {"focus: [kubernetes, observability, automation]\n"}
                {"next:  open /docs/intro\n"}
              </code>
            </pre>
            <div className={styles.heroActions}>
              <Link
                className={clsx(
                  "button button--secondary button--lg",
                  styles.heroActionButton,
                  styles.heroActionPrimary,
                )}
                to="/docs/intro"
              >
                open /docs
              </Link>
              <Link
                className={clsx(
                  "button button--outline button--lg",
                  styles.heroActionButton,
                )}
                to="/docs/journal"
              >
                open /journal
              </Link>
            </div>
            <div className={styles.heroMetrics}>
              <div className={styles.stat}>
                <span className={styles.statLabel}>playbooks</span>
                <span className={styles.statValue}>120+</span>
              </div>
              <div className={styles.stat}>
                <span className={styles.statLabel}>dashboards</span>
                <span className={styles.statValue}>45</span>
              </div>
              <div className={styles.stat}>
                <span className={styles.statLabel}>pipelines</span>
                <span className={styles.statValue}>15</span>
              </div>
            </div>
            <div className={styles.heroConsole}>
              <div className={styles.consoleHeader}>
                <span>kvanni@notes ~/console</span>
                <span className={styles.consoleStatus}>RUNNING</span>
              </div>
              <div className={styles.consoleBody}>
                {consoleCommands.map((line) => (
                  <div key={line.command} className={styles.consoleLine}>
                    <span className={styles.consolePrompt}>$</span>
                    <div>
                      <p className={styles.consoleCommand}>{line.command}</p>
                      <p className={styles.consoleResult}>{line.result}</p>
                    </div>
                  </div>
                ))}
              </div>
              <div className={styles.consoleFooter}>
                {consoleSummary.map((item) => (
                  <div key={item.label}>
                    <p className={styles.detailLabel}>{item.label}</p>
                    <p className={styles.detailValue}>{item.value}</p>
                  </div>
                ))}
              </div>
            </div>
          </div>
          <div className={styles.panelStack}>
            <div className={clsx(styles.statusCard, styles.terminalCard)}>
              <div className={styles.terminalHeader}>
                <div className={styles.terminalButtons}>
                  <span />
                  <span />
                  <span />
                </div>
                <span className={styles.terminalTitle}>cluster-health</span>
                <span className={styles.statusBadge}>OK</span>
              </div>
              <div className={styles.terminalBody}>
                <dl className={styles.statusList}>
                  {clusterHealth.map((item) => (
                    <div key={item.label}>
                      <dt>{item.label}</dt>
                      <dd>{item.value}</dd>
                    </div>
                  ))}
                </dl>
              </div>
            </div>
            <div className={clsx(styles.statusCard, styles.terminalCard)}>
              <div className={styles.terminalHeader}>
                <div className={styles.terminalButtons}>
                  <span />
                  <span />
                  <span />
                </div>
                <span className={styles.terminalTitle}>prometheus</span>
                <span
                  className={clsx(styles.statusBadge, styles.badgeSecondary)}
                >
                  WATCH
                </span>
              </div>
              <div className={styles.terminalBody}>
                <dl className={styles.statusList}>
                  {monitorStatus.map((item) => (
                    <div key={item.label}>
                      <dt>{item.label}</dt>
                      <dd>{item.value}</dd>
                    </div>
                  ))}
                </dl>
              </div>
            </div>
            <div className={clsx(styles.incidentCard, styles.terminalCard)}>
              <div className={styles.terminalHeader}>
                <div className={styles.terminalButtons}>
                  <span />
                  <span />
                  <span />
                </div>
                <span className={styles.terminalTitle}>incident.sh</span>
                <span className={styles.statusBadge}>RUNBOOK</span>
              </div>
              <div className={styles.terminalBody}>
                <ol className={styles.incidentList}>
                  {incidentQuickstart.map((step, idx) => (
                    <li key={step}>
                      <span className={styles.stepIndex}>{idx + 1}</span>
                      <span>{step}</span>
                    </li>
                  ))}
                </ol>
              </div>
            </div>
          </div>
        </div>
      </div>
    </header>
  );
}

function SectionTitle({
  title,
  subtitle,
  summary,
}: {
  title: string;
  subtitle: string;
  summary: string;
}): ReactNode {
  return (
    <div className="text--center">
      <p className="section-title">{title}</p>
      <Heading as="h2" className={styles.sectionHeading}>
        {subtitle}
      </Heading>
      <p className="section-subtitle">{summary}</p>
    </div>
  );
}

export default function Home(): ReactNode {
  return (
    <Layout
      title="OpsTrack · 运维工程师工作记录"
      description="记录 Kubernetes、Prometheus、DevOps、Shell、Python、数据库等运维工程师知识与工作日志"
    >
      <HomepageHeader />
      <main>
        <section className={styles.section}>
          <div className="container">
            <SectionTitle
              title="领域笔记"
              subtitle="不是教程合集，而是可复用经验库"
              summary="以 deploy / diagnose / rollback 的节奏，沉淀 Kubernetes、Prometheus、DevOps、Shell、Python 的 Runbook。"
            />
            <div className={styles.noteGrid}>
              {domainNotes.map((note) => (
                <div
                  key={note.title}
                  className={clsx(styles.noteCard, styles.terminalCard)}
                >
                  <div className={styles.terminalHeader}>
                    <div className={styles.terminalButtons}>
                      <span />
                      <span />
                      <span />
                    </div>
                    <span className={styles.terminalTitle}>{note.title}</span>
                    <span className={styles.noteIcon}>{note.icon}</span>
                  </div>
                  <div className={styles.terminalBody}>
                    <p className={styles.promptLine}>
                      <span className={styles.promptUser}>kvanni@notes</span> ~ %
                      open {note.title.toLowerCase()}
                    </p>
                    <p className={styles.noteMeta}>{note.meta}</p>
                    <p className={styles.noteDescription}>{note.description}</p>
                    <Link className={styles.cardLink} to={note.link}>
                      打开笔记 →
                    </Link>
                  </div>
                </div>
              ))}
            </div>
          </div>
        </section>

        <HomepageFeatures />
      </main>
    </Layout>
  );
}
