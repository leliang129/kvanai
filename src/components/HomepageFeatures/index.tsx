import type { ReactNode } from "react";
import clsx from "clsx";
import Link from "@docusaurus/Link";
import Heading from "@theme/Heading";
import styles from "./styles.module.css";

type FeatureItem = {
  title: string;
  highlight: string;
  description: ReactNode;
  link: string;
  linkLabel: string;
};

function toTerminalTitle(input: string): string {
  const firstToken = input.split(/[+/&]/)[0]?.trim() ?? input;
  return firstToken
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/(^-|-$)/g, "");
}

const FeatureList: FeatureItem[] = [
  {
    title: "生产级巡检",
    highlight: "Kubernetes",
    description: (
      <>
        集中记录集群健康检查、升级策略与容量预案，覆盖 kube-apiserver、etcd
        以及常见 控制平面组件的巡检清单。
      </>
    ),
    link: "/docs/platform/kubernetes",
    linkLabel: "查看巡检手册",
  },
  {
    title: "可观测矩阵",
    highlight: "Prometheus + Grafana",
    description: (
      <>
        从指标、日志到追踪的三栈方案，沉淀告警模板、SLO 仪表盘与多集群
        Prometheus 联邦 配置，及时准备感知系统运行状况。
      </>
    ),
    link: "/docs/observability/prometheus",
    linkLabel: "搭建监控",
  },
  {
    title: "自动化流水线",
    highlight: "DevOps & Shell/Python",
    description: (
      <>
        汇总 CI/CD 模板、常用 Shell/Python 工具脚本与应急响应
        Playbook，提升运维交付效率。
      </>
    ),
    link: "/docs/automation/devops",
    linkLabel: "设计流水线",
  },
];

function Feature({
  title,
  highlight,
  description,
  link,
  linkLabel,
}: FeatureItem) {
  const terminalTitle = toTerminalTitle(highlight) || "docs";
  return (
    <div className={clsx("col col--4")}>
      <div className={styles.featureCard}>
        <div className={styles.featureHeader}>
          <div className={styles.terminalButtons}>
            <span />
            <span />
            <span />
          </div>
          <span className={styles.featureTitle}>{terminalTitle}</span>
          <span className={styles.featureIcon}>
            {highlight.slice(0, 2).toUpperCase()}
          </span>
        </div>
        <div className={styles.featureBody}>
          <p className={styles.promptLine}>
            <span className={styles.promptUser}>kvanni@notes</span> ~/docs % open{" "}
            {terminalTitle}
          </p>
          <Heading as="h3" className={styles.featureHeading}>
            {title}
          </Heading>
          <p className={styles.featureDescription}>{description}</p>
          <Link className={styles.featureLink} to={link}>
            {linkLabel} →
          </Link>
        </div>
      </div>
    </div>
  );
}

export default function HomepageFeatures(): ReactNode {
  return (
    <section className={styles.features}>
      <div className="container">
        <div className="row">
          {FeatureList.map((props, idx) => (
            <Feature key={idx} {...props} />
          ))}
        </div>
      </div>
    </section>
  );
}
