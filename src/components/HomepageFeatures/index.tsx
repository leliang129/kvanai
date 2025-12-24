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
        Prometheus 联邦 配置。
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
  return (
    <div className={clsx("col col--4")}>
      <div className={styles.featureCard}>
        <div className={styles.featureIcon}>
          {highlight.slice(0, 2).toUpperCase()}
        </div>
        <Heading as="h3">{title}</Heading>
        <p>{description}</p>
        <Link className={styles.featureLink} to={link}>
          {linkLabel} →
        </Link>
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
