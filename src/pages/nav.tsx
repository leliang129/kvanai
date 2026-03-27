import React, { useState } from 'react';
import Layout from '@theme/Layout';

// --- 数据配置 ---
const NAV_DATA = [
  {
    category: 'AI & 生产力',
    items: [
      {
        title: 'ChatGPT',
        desc: 'OpenAI 交互终端',
        url: 'https://chatgpt.com/',
        color: '#10a37f',
      },
      {
        title: 'Claude',
        desc: 'Anthropic 智能助手',
        url: 'https://claude.ai',
        color: '#d97757',
      },
      {
        title: 'Google Gemini',
        desc: 'Google Gemini AI 入口',
        url: 'https://gemini.google.com/',
        color: '#f97316',
      },
      {
        title: 'Github',
        desc: '代码托管与协作',
        url: 'https://github.com',
        color: '#24292f',
      },
      {
        title: 'LOVART 设计',
        desc: 'LOVART AI 设计平台',
        url: 'https://www.lovart.ai/',
        color: '#ec4899',
      },
      {
        title: 'FastGPT',
        desc: '开源知识库型对话平台',
        url: 'https://fastgpt.io/zh',
        color: '#0ea5e9',
      },
      {
        title: 'n8n',
        desc: '开源工作流自动化平台',
        url: 'https://github.com/n8n-io/n8n',
        color: '#22c55e',
      },
      {
        title: 'Dify',
        desc: '开源 LLM 应用开发平台',
        url: 'https://docs.dify.ai/zh-hans/introduction',
        color: '#6366f1',
      },
    ],
  },
  {
    category: '运维 & 云原生',
    items: [
      {
        title: 'Kubectl Cheat',
        desc: 'K8s 常用命令速查',
        url: 'https://kubernetes.io/docs/reference/kubectl/cheatsheet/',
        color: '#326ce5',
      },
      {
        title: 'Prometheus',
        desc: '监控与告警系统',
        url: 'https://prometheus.io',
        color: '#e6522c',
      },
      {
        title: 'Grafana',
        desc: '可观测性仪表盘与可视化平台',
        url: 'https://grafana.com/',
        color: '#f59e0b',
      },
      {
        title: 'VictoriaMetrics',
        desc: '高性能时序数据库与监控存储方案',
        url: 'https://docs.victoriametrics.com/quick-start/',
        color: '#06b6d4',
      },
      {
        title: 'Elastic Stack',
        desc: '日志检索、分析与可视化平台',
        url: 'https://www.elastic.co/docs/reference',
        color: '#22c55e',
      },
      {
        title: 'SkyWalking',
        desc: '分布式追踪与应用性能监控平台',
        url: 'https://skywalking.apache.org/',
        color: '#8b5cf6',
      },
      {
        title: 'GitLab',
        desc: '代码托管与 CI/CD DevOps 平台',
        url: 'https://docs.gitlab.com/',
        color: '#fc6d26',
      },
      {
        title: 'Nginx',
        desc: 'Web 服务器与反向代理官方文档',
        url: 'https://nginx.org/en/docs/',
        color: '#009639',
      },
      {
        title: 'Ansible',
        desc: '自动化运维与配置管理官方文档',
        url: 'https://docs.ansible.com/projects/ansible/latest/index.html',
        color: '#ee0000',
      },
      {
        title: 'Jenkins',
        desc: '自动化构建与持续集成服务',
        url: 'https://www.jenkins.io/',
        color: '#2563eb',
      },
      {
        title: 'Artifact Hub',
        desc: '寻找 Helm Charts',
        url: 'https://artifacthub.io',
        color: '#417598',
      },
      {
        title: 'Docker',
        desc: 'Docker 官方文档入口',
        url: 'https://docs.docker.com/reference/',
        color: '#2496ed',
      },
      {
        title: 'Dockerfile 参考文档',
        desc: 'Dockerfile 指令与最佳实践',
        url: 'https://deepzz.com/post/dockerfile-reference.html',
        color: '#0ea5e9',
      },
      {
        title: 'Harbor',
        desc: '企业级 OCI 镜像仓库与制品管理',
        url: 'https://goharbor.io/',
        color: '#2563eb',
      },
      {
        title: 'DockerCompose 生成',
        desc: '将 docker run 命令转换为 Compose',
        url: 'https://www.composerize.com/',
        color: '#22c55e',
      },
      {
        title: 'K3s',
        desc: '轻量级 Kubernetes 发行版文档',
        url: 'https://docs.k3s.io/zh/',
        color: '#6366f1',
      },
      {
        title: 'Kind',
        desc: '基于容器的本地 K8s 集群',
        url: 'https://kind.sigs.k8s.io/',
        color: '#14b8a6',
      },
      {
        title: 'K8s API 文档',
        desc: 'Kubernetes API 参考文档',
        url: 'https://kubernetes.io/docs/reference/kubernetes-api/',
        color: '#2563eb',
      },
      {
        title: 'Helm 文档',
        desc: 'Helm 官方文档',
        url: 'https://helm.sh/',
        color: '#4b5563',
      },
      {
        title: 'Registry Explorer',
        desc: '容器镜像仓库浏览与调试工具',
        url: 'https://explore.ggcr.dev/',
        color: '#0f766e',
      },
      {
        title: '渡渡鸟镜像同步',
        desc: '国内 Docker 镜像同步服务',
        url: 'https://docker.aityp.com/',
        color: '#e11d48',
      },
      {
        title: 'Argo CD',
        desc: 'Kubernetes GitOps 持续部署平台',
        url: 'https://argo-cd.readthedocs.io/',
        color: '#ef4444',
      },
      {
        title: 'Argo Rollouts',
        desc: '蓝绿 / 灰度 / 金丝雀发布控制器',
        url: 'https://argo-rollouts.readthedocs.io/',
        color: '#f97316',
      },
    ],
  },
  {
    category: '镜像源 & 仓库',
    items: [
      {
        title: '清华源',
        desc: '清华大学开源软件镜像站',
        url: 'https://mirrors.tuna.tsinghua.edu.cn/',
        color: '#2563eb',
      },
      {
        title: '阿里源',
        desc: '阿里云开源镜像站',
        url: 'https://mirrors.aliyun.com/',
        color: '#f97316',
      },
      {
        title: '华为源',
        desc: '华为云开源镜像站',
        url: 'https://mirrors.huaweicloud.com/',
        color: '#22c55e',
      },
      {
        title: 'Maven 中央仓库',
        desc: '通用 Maven 依赖查询',
        url: 'https://mvnrepository.com/',
        color: '#6366f1',
      },
      {
        title: 'Maven 阿里仓库',
        desc: '阿里云 Maven 仓库与使用指引',
        url: 'https://maven.aliyun.com/mvn/guide',
        color: '#f59e0b',
      },
      {
        title: 'NPM 淘宝源',
        desc: '淘宝 NPM 镜像（npmmirror）',
        url: 'https://npmmirror.com/',
        color: '#06b6d4',
      },
    ],
  },
  {
    category: '在线工具 & 参考',
    items: [
      {
        title: '常用工具合集',
        desc: '开发 / 运维常用在线工具集合',
        url: 'https://ctool.dev/',
        color: '#0ea5e9',
      },
      {
        title: 'Crontab 可视化',
        desc: 'Crontab 表达式可视化生成器',
        url: 'https://crontab-generator.org/',
        color: '#22c55e',
      },
      {
        title: '快速参考备忘录',
        desc: '命令/语法速查参考（reference）',
        url: 'https://wangchujiang.com/reference/',
        color: '#f59e0b',
      },
      {
        title: 'IP 测试工具',
        desc: 'Ping / 网络连通性测试',
        url: 'https://ping.sx/ping',
        color: '#6366f1',
      },
      {
        title: 'Excalidraw',
        desc: '手绘风架构/流程图工具',
        url: 'https://excalidraw.com/',
        color: '#ec4899',
      },
      {
        title: 'OpenJDK 镜像',
        desc: 'Adoptium OpenJDK 下载',
        url: 'https://adoptium.net/zh-CN/',
        color: '#1d4ed8',
      },
      {
        title: 'JDK 下载站',
        desc: '国内 JDK 下载聚合站',
        url: 'https://www.injdk.cn/',
        color: '#9333ea',
      },
      {
        title: 'OpenJDK 镜像站',
        desc: '清华 OpenJDK 镜像（Adoptium）',
        url: 'https://mirrors.tuna.tsinghua.edu.cn/Adoptium/',
        color: '#0f766e',
      },
      {
        title: 'Curl 转换工具',
        desc: '将 curl 转为多语言代码',
        url: 'https://curlconverter.com/',
        color: '#f97316',
      },
      {
        title: '临时邮箱',
        desc: '一次性邮箱服务（TempMail）',
        url: 'https://tempmail.plus/zh/#!',
        color: '#64748b',
      },
      {
        title: 'Email Once',
        desc: '一次性邮箱服务（Email Once）',
        url: 'https://email-once.com/',
        color: '#22c55e',
      },
    ],
  },
];

export default function NavigationPage(): JSX.Element {
  const [searchQuery, setSearchQuery] = useState('');

  // 过滤逻辑
  const filteredData = NAV_DATA.map((section) => ({
    ...section,
    items: section.items.filter(
      (item) =>
        item.title.toLowerCase().includes(searchQuery.toLowerCase()) ||
        item.desc.toLowerCase().includes(searchQuery.toLowerCase()),
    ),
  })).filter((section) => section.items.length > 0);

  return (
    <Layout title="资源导航">
      <main
        style={{
          padding: '2rem 1rem',
          minHeight: 'calc(100vh - 60px)',
          // 使用 CSS 变量自动适配深浅色
          backgroundColor: 'var(--ifm-background-color)',
          color: 'var(--ifm-font-color-base)',
        }}
      >
        <div style={{ maxWidth: '1200px', margin: '0 auto' }}>
          {/* Header：紧凑型设计 */}
          <header
            style={{
              display: 'flex',
              justifyContent: 'space-between',
              alignItems: 'center',
              marginBottom: '2rem',
              borderBottom: '1px solid var(--ifm-toc-border-color)',
              paddingBottom: '1rem',
            }}
          >
            <h1 style={{ fontSize: '1.5rem', fontWeight: 'bold', margin: 0 }}>
              Portal / 导航
            </h1>
            <input
              type="text"
              placeholder="快速搜索..."
              onChange={(e) => setSearchQuery(e.target.value)}
              style={{
                padding: '0.4rem 0.8rem',
                borderRadius: '6px',
                border: '1px solid var(--ifm-color-emphasis-300)',
                backgroundColor: 'var(--ifm-background-surface-color)',
                color: 'var(--ifm-font-color-base)',
                outline: 'none',
                width: '200px',
              }}
            />
          </header>

          {/* 导航网格 */}
          {filteredData.map((section, idx) => (
            <div key={idx} style={{ marginBottom: '2rem' }}>
              <div
                style={{
                  fontSize: '0.8rem',
                  fontWeight: 'bold',
                  opacity: 0.5,
                  marginBottom: '1rem',
                  textTransform: 'uppercase',
                }}
              >
                {section.category}
              </div>

              <div
                style={{
                  display: 'grid',
                  gridTemplateColumns: 'repeat(auto-fill, minmax(200px, 1fr))',
                  gap: '1rem',
                }}
              >
                {section.items.map((item, i) => (
                  <a
                    key={i}
                    href={item.url}
                    target="_blank"
                    rel="noreferrer"
                    style={{
                      display: 'flex',
                      alignItems: 'center',
                      padding: '0.8rem',
                      borderRadius: '8px',
                      textDecoration: 'none',
                      color: 'inherit',
                      border: '1px solid var(--ifm-color-emphasis-200)',
                      backgroundColor: 'var(--ifm-background-surface-color)',
                      transition: 'all 0.2s ease',
                    }}
                    onMouseOver={(e) => {
                      e.currentTarget.style.borderColor = 'var(--ifm-color-primary)';
                      e.currentTarget.style.transform = 'translateY(-2px)';
                    }}
                    onMouseOut={(e) => {
                      e.currentTarget.style.borderColor = 'var(--ifm-color-emphasis-200)';
                      e.currentTarget.style.transform = 'translateY(0)';
                    }}
                  >
                    <div
                      style={{
                        width: '32px',
                        height: '32px',
                        borderRadius: '4px',
                        backgroundColor: item.color,
                        marginRight: '10px',
                        flexShrink: 0,
                        display: 'flex',
                        alignItems: 'center',
                        justifyContent: 'center',
                        color: '#fff',
                        fontWeight: 'bold',
                        fontSize: '0.9rem',
                      }}
                    >
                      {item.title.charAt(0)}
                    </div>
                    <div style={{ overflow: 'hidden' }}>
                      <div
                        style={{
                          fontWeight: 600,
                          fontSize: '0.9rem',
                          whiteSpace: 'nowrap',
                          overflow: 'hidden',
                          textOverflow: 'ellipsis',
                        }}
                      >
                        {item.title}
                      </div>
                      <div
                        style={{
                          fontSize: '0.7rem',
                          opacity: 0.6,
                          whiteSpace: 'nowrap',
                          overflow: 'hidden',
                          textOverflow: 'ellipsis',
                        }}
                      >
                        {item.desc}
                      </div>
                    </div>
                  </a>
                ))}
              </div>
            </div>
          ))}
        </div>
      </main>
    </Layout>
  );
}
