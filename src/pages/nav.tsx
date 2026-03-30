import React, { useState } from 'react';
import Layout from '@theme/Layout';

// --- 数据配置 (保持全量) ---
const NAV_DATA = [
  {
    category: 'AI & 生产力',
    id: 'ai-productivity',
    items: [
      { title: 'ChatGPT', desc: 'OpenAI 交互终端', url: 'https://chatgpt.com/', color: '#10a37f' },
      { title: 'Claude', desc: 'Anthropic 智能助手', url: 'https://claude.ai', color: '#d97757' },
      { title: 'Google Gemini', desc: 'Google Gemini AI 入口', url: 'https://gemini.google.com/', color: '#f97316' },
      { title: 'Github', desc: '代码托管与协作', url: 'https://github.com', color: '#24292f' },
      { title: 'LOVART 设计', desc: 'LOVART AI 设计平台', url: 'https://www.lovart.ai/', color: '#ec4899' },
      { title: 'FastGPT', desc: '开源知识库型对话平台', url: 'https://fastgpt.io/zh', color: '#0ea5e9' },
      { title: 'n8n', desc: '开源工作流自动化平台', url: 'https://github.com/n8n-io/n8n', color: '#22c55e' },
      { title: 'Dify', desc: '开源 LLM 应用开发平台', url: 'https://docs.dify.ai/zh-hans/introduction', color: '#6366f1' },
    ],
  },
  {
    category: '运维 & 云原生',
    id: 'ops-cloud-native',
    items: [
      { title: 'Kubectl Cheat', desc: 'K8s 常用命令速查', url: 'https://kubernetes.io/docs/reference/kubectl/cheatsheet/', color: '#326ce5' },
      { title: 'Prometheus', desc: '监控与告警系统', url: 'https://prometheus.io', color: '#e6522c' },
      { title: 'Grafana', desc: '可观测性仪表盘', url: 'https://grafana.com/', color: '#f59e0b' },
      { title: 'VictoriaMetrics', desc: '高性能时序数据库', url: 'https://docs.victoriametrics.com/quick-start/', color: '#06b6d4' },
      { title: 'Elastic Stack', desc: '日志检索与分析平台', url: 'https://www.elastic.co/docs/reference', color: '#22c55e' },
      { title: 'SkyWalking', desc: '应用性能监控平台', url: 'https://skywalking.apache.org/', color: '#8b5cf6' },
      { title: 'GitLab Docs', desc: 'GitLab 官方文档', url: 'https://docs.gitlab.com/', color: '#fc6d26' },
      { title: 'Nginx Docs', desc: 'Web 服务器参考', url: 'https://nginx.org/en/docs/', color: '#009639' },
      { title: 'Ansible Docs', desc: '自动化运维文档', url: 'https://docs.ansible.com/', color: '#ee0000' },
      { title: 'Jenkins Docs', desc: '使用手册与参考', url: 'https://www.jenkins.io/doc/', color: '#d24939' },
      { title: 'Artifact Hub', desc: '寻找 Helm Charts', url: 'https://artifacthub.io', color: '#417598' },
      { title: 'Docker Docs', desc: 'Docker 官方参考', url: 'https://docs.docker.com/reference/', color: '#2496ed' },
      { title: 'Dockerfile 参考', desc: '指令与最佳实践', url: 'https://deepzz.com/post/dockerfile-reference.html', color: '#0ea5e9' },
      { title: 'Harbor', desc: 'OCI 镜像仓库管理', url: 'https://goharbor.io/', color: '#2563eb' },
      { title: 'DockerCompose 生成', desc: 'Run 转 Compose', url: 'https://www.composerize.com/', color: '#22c55e' },
      { title: 'K3s', desc: '轻量级 K8s 文档', url: 'https://docs.k3s.io/zh/', color: '#6366f1' },
      { title: 'Kind', desc: '容器内 K8s 集群', url: 'https://kind.sigs.k8s.io/', color: '#14b8a6' },
      { title: 'K8s API', desc: 'Kubernetes API 参考', url: 'https://kubernetes.io/docs/reference/kubernetes-api/', color: '#2563eb' },
      { title: 'Helm 文档', desc: 'Helm 官方文档', url: 'https://helm.sh/', color: '#4b5563' },
      { title: 'Registry Explorer', desc: '镜像仓库调试工具', url: 'https://explore.ggcr.dev/', color: '#0f766e' },
      { title: '渡渡鸟镜像', desc: '国内 Docker 镜像同步', url: 'https://docker.aityp.com/', color: '#e11d48' },
      { title: 'Argo CD', desc: 'GitOps 持续部署', url: 'https://argo-cd.readthedocs.io/', color: '#ef4444' },
      { title: 'Argo Rollouts', desc: '蓝绿/灰度发布控制器', url: 'https://argo-rollouts.readthedocs.io/', color: '#f97316' },
    ],
  },
  {
    category: '镜像源 & 仓库',
    id: 'mirrors',
    items: [
      { title: '清华源', desc: '开源软件镜像站', url: 'https://mirrors.tuna.tsinghua.edu.cn/', color: '#2563eb' },
      { title: '阿里源', desc: '阿里云开源镜像站', url: 'https://mirrors.aliyun.com/', color: '#f97316' },
      { title: '华为源', desc: '华为云开源镜像站', url: 'https://mirrors.huaweicloud.com/', color: '#22c55e' },
      { title: 'Maven 中央仓库', desc: 'Maven 依赖查询', url: 'https://mvnrepository.com/', color: '#6366f1' },
      { title: 'Maven 阿里', desc: '阿里 Maven 仓库指引', url: 'https://maven.aliyun.com/mvn/guide', color: '#f59e0b' },
      { title: 'NPM 淘宝源', desc: '淘宝 NPM 镜像站', url: 'https://npmmirror.com/', color: '#06b6d4' },
    ],
  },
  {
    category: '在线工具 & 参考',
    id: 'tools',
    items: [
      { title: '常用工具合集', desc: '在线工具集合 (ctool)', url: 'https://ctool.dev/', color: '#0ea5e9' },
      { title: 'Crontab 生成', desc: '表达式可视化生成', url: 'https://crontab-generator.org/', color: '#22c55e' },
      { title: '快速参考', desc: '命令/语法速查参考', url: 'https://wangchujiang.com/reference/', color: '#f59e0b' },
      { title: 'IP 测试', desc: 'Ping/网络连通性', url: 'https://ping.sx/ping', color: '#6366f1' },
      { title: 'Excalidraw', desc: '手绘风流程图工具', url: 'https://excalidraw.com/', color: '#ec4899' },
      { title: 'Curl 转换', desc: 'Curl 转多语言代码', url: 'https://curlconverter.com/', color: '#f97316' },
      { title: '临时邮箱 Plus', desc: 'TempMailPlus', url: 'https://tempmail.plus/zh/#!', color: '#64748b' },
      { title: '临时邮箱 Once', desc: 'Email Once', url: 'https://email-once.com/', color: '#22c55e' },
    ],
  },
  {
    category: '软件下载',
    id: 'downloads',
    items: [
      { title: 'Jenkins Download', desc: '安装包与历史版本', url: 'https://get.jenkins.io/', color: '#2563eb' },
      { title: 'GitLab Packages', desc: 'GitLab 官方包下载', url: 'https://packages.gitlab.com/gitlab/gitlab-ce', color: '#fc6d26' },
      { title: 'GitLab 清华', desc: 'GitLab 软件包镜像', url: 'https://mirrors.tuna.tsinghua.edu.cn/gitlab-ce/', color: '#2563eb' },
      { title: 'MySQL Download', desc: 'MySQL Community Server 官方下载', url: 'https://dev.mysql.com/downloads/mysql/', color: '#00758f' },
      { title: 'Redis Download', desc: 'Redis 官方下载与发行版本', url: 'https://redis.io/downloads/', color: '#dc382d' },
      { title: 'Kafka Download', desc: 'Apache Kafka 官方下载页面', url: 'https://kafka.apache.org/downloads.html', color: '#231f20' },
      { title: 'SkyWalking Download', desc: 'Apache SkyWalking 官方下载页面', url: 'https://skywalking.apache.org/downloads/', color: '#8b5cf6' },
      { title: 'Docker Download', desc: 'Docker Desktop 官方下载入口', url: 'https://www.docker.com/products/docker-desktop/', color: '#2496ed' },
      { title: 'OpenJDK 镜像', desc: 'Adoptium 下载', url: 'https://adoptium.net/zh-CN/', color: '#1d4ed8' },
      { title: 'JDK 下载站', desc: '国内 JDK 聚合下载', url: 'https://www.injdk.cn/', color: '#9333ea' },
      { title: 'Adoptium 清华', desc: '清华 OpenJDK 镜像', url: 'https://mirrors.tuna.tsinghua.edu.cn/Adoptium/', color: '#0f766e' },
    ],
  },
];

export default function NavigationPage() {
  const [searchQuery, setSearchQuery] = useState('');
  const [activeId, setActiveId] = useState(NAV_DATA[0].id);

  const filteredData = NAV_DATA.map((section) => ({
    ...section,
    items: section.items.filter(
      (item) =>
        item.title.toLowerCase().includes(searchQuery.toLowerCase()) ||
        item.desc.toLowerCase().includes(searchQuery.toLowerCase()),
    ),
  })).filter((section) => section.items.length > 0);

  const scrollToSection = (id) => {
    const element = document.getElementById(id);
    if (element) {
      element.scrollIntoView({ behavior: 'smooth' });
      setActiveId(id);
    }
  };

  return (
    <Layout title="资源导航" noFooter={true}>
      <main style={{ display: 'flex', height: 'calc(100vh - var(--ifm-navbar-height))', overflow: 'hidden', backgroundColor: 'var(--ifm-background-color)' }}>
        
        {/* --- 左侧菜单栏：调大宽度至 260px --- */}
        <aside style={{ 
          width: '260px', 
          borderRight: '1px solid var(--ifm-toc-border-color)', 
          backgroundColor: 'var(--ifm-background-surface-color)', 
          display: 'flex', 
          flexDirection: 'column', 
          flexShrink: 0 
        }}>
          <div style={{ padding: '1.2rem 1rem' }}>
            <input
              type="text"
              placeholder="搜索资源..."
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              style={{ 
                width: '100%', 
                padding: '0.6rem 0.8rem', 
                borderRadius: '8px', 
                border: '1px solid var(--ifm-color-emphasis-300)', 
                backgroundColor: 'var(--ifm-background-color)', 
                color: 'var(--ifm-font-color-base)', 
                fontSize: '0.9rem', 
                outline: 'none' 
              }}
            />
          </div>
          <nav style={{ flex: 1, overflowY: 'auto', padding: '0 0.6rem' }}>
            {filteredData.map((section) => (
              <div
                key={section.id}
                onClick={() => scrollToSection(section.id)}
                style={{ 
                  padding: '0.8rem 1rem', 
                  borderRadius: '6px', 
                  cursor: 'pointer', 
                  fontSize: '0.95rem', // 字体略微调大
                  marginBottom: '6px', 
                  transition: 'all 0.2s ease', 
                  backgroundColor: activeId === section.id ? 'var(--ifm-color-primary-lighter)' : 'transparent', 
                  color: activeId === section.id ? 'var(--ifm-color-primary-contrast-background)' : 'inherit', 
                  fontWeight: activeId === section.id ? 'bold' : 'normal' 
                }}
                onMouseOver={(e) => {
                    if (activeId !== section.id) e.currentTarget.style.backgroundColor = 'var(--ifm-hover-overlay)';
                }}
                onMouseOut={(e) => {
                    if (activeId !== section.id) e.currentTarget.style.backgroundColor = 'transparent';
                }}
              >
                {section.category}
              </div>
            ))}
          </nav>
        </aside>

        {/* --- 右侧内容区：保持固定块大小 224*70 --- */}
        <section style={{ flex: 1, overflowY: 'auto', padding: '1.5rem 2rem', scrollBehavior: 'smooth' }}>
          <div style={{ width: '100%' }}>
            <h1 style={{ marginBottom: '2rem', fontSize: '1.8rem', fontWeight: 'bold' }}>Portal 导航</h1>
            
            {filteredData.map((section) => (
              <div key={section.id} id={section.id} style={{ marginBottom: '3rem', scrollMarginTop: '1rem' }}>
                <h2 style={{ 
                  fontSize: '1.1rem', 
                  borderLeft: '4px solid var(--ifm-color-primary)', 
                  paddingLeft: '12px', 
                  marginBottom: '1.2rem', 
                  color: 'var(--ifm-color-primary)', 
                  fontWeight: 'bold' 
                }}>
                  {section.category}
                </h2>

                <div style={{ 
                  display: 'grid', 
                  gridTemplateColumns: 'repeat(auto-fill, 224px)', 
                  gap: '1rem' 
                }}>
                  {section.items.map((item, i) => (
                    <a
                      key={i}
                      href={item.url}
                      target="_blank"
                      rel="noreferrer"
                      style={{ 
                        display: 'flex', 
                        alignItems: 'center', 
                        width: '224px', 
                        height: '70px', 
                        padding: '0 1rem', 
                        borderRadius: '10px', 
                        textDecoration: 'none', 
                        color: 'inherit', 
                        border: '1px solid var(--ifm-color-emphasis-200)', 
                        backgroundColor: 'var(--ifm-background-surface-color)', 
                        transition: 'all 0.25s ease',
                        boxSizing: 'border-box'
                      }}
                      onMouseOver={(e) => { 
                        e.currentTarget.style.borderColor = 'var(--ifm-color-primary)'; 
                        e.currentTarget.style.transform = 'translateY(-3px)'; 
                        e.currentTarget.style.boxShadow = '0 4px 12px rgba(0,0,0,0.08)';
                      }}
                      onMouseOut={(e) => { 
                        e.currentTarget.style.borderColor = 'var(--ifm-color-emphasis-200)'; 
                        e.currentTarget.style.transform = 'translateY(0)'; 
                        e.currentTarget.style.boxShadow = 'none';
                      }}
                    >
                      <div style={{ 
                        width: '36px', 
                        height: '36px', 
                        borderRadius: '8px', 
                        backgroundColor: item.color, 
                        marginRight: '12px', 
                        flexShrink: 0, 
                        display: 'flex', 
                        alignItems: 'center', 
                        justifyContent: 'center', 
                        color: '#fff', 
                        fontWeight: 'bold', 
                        fontSize: '1.1rem' 
                      }}>
                        {item.title.charAt(0)}
                      </div>
                      <div style={{ overflow: 'hidden', display: 'flex', flexDirection: 'column', justifyContent: 'center' }}>
                        <div style={{ 
                          fontWeight: 600, 
                          fontSize: '0.95rem', 
                          lineHeight: '1.2',
                          marginBottom: '3px',
                          whiteSpace: 'nowrap', 
                          overflow: 'hidden', 
                          textOverflow: 'ellipsis' 
                        }}>
                          {item.title}
                        </div>
                        <div style={{ 
                          fontSize: '0.75rem', 
                          opacity: 0.5, 
                          lineHeight: '1.2',
                          whiteSpace: 'nowrap', 
                          overflow: 'hidden', 
                          textOverflow: 'ellipsis' 
                        }}>
                          {item.desc}
                        </div>
                      </div>
                    </a>
                  ))}
                </div>
              </div>
            ))}
          </div>
        </section>
      </main>
    </Layout>
  );
}