import React, { useState, useEffect } from 'react';
import Layout from '@theme/Layout';
import Link from '@docusaurus/Link';
import { useColorMode } from '@docusaurus/theme-common';

// --- 1. 工业手册主题配置 ---
const getTheme = (isDark) => ({
  bg: isDark ? '#121214' : '#fcfcfc',
  cardBg: isDark ? '#1a1b1e' : '#ffffff',
  border: isDark ? '#2d2e32' : '#e2e8f0',
  text: isDark ? '#e2e8f0' : '#000000',
  subText: isDark ? '#586069' : '#64748b',
  accent: '#326ce5', // K8s 蓝色
  mono: '"JetBrains Mono", "Fira Code", monospace',
  sans: '"Inter", "PingFang SC", "Microsoft YaHei", sans-serif',
});

// --- 2. 基础组件：线稿图标 ---
const Icon = ({ d, color }) => (
  <svg
    width="20" height="20" viewBox="0 0 24 24"
    fill="none" stroke={color || "currentColor"}
    strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"
    style={{ flexShrink: 0, marginRight: '10px' }}
  >
    <path d={d} />
  </svg>
);

// --- 3. 基础组件：侧边指示灯条目 ---
const ManualItem = ({ to, label, theme, type = 'dot', dotColor = '#2ea44f' }) => (
  <Link to={to} style={{
    display: 'flex',
    alignItems: 'center',
    padding: '8px 0',
    color: theme.text,
    textDecoration: 'none',
    fontFamily: theme.mono,
    fontSize: '13px',
    borderBottom: `1px solid ${theme.border}`,
    transition: 'opacity 0.2s',
  }} className="manual-item">
    {type === 'dot' ? (
      <span style={{ width: '6px', height: '6px', borderRadius: '50%', backgroundColor: dotColor, marginRight: '12px', opacity: 0.6 }} />
    ) : (
      <span style={{ width: '8px', height: '8px', backgroundColor: dotColor, marginRight: '10px', opacity: 0.6 }} />
    )}
    {label}
  </Link>
);

const DashboardContent = () => {
  const { colorMode } = useColorMode();
  const isDark = colorMode === 'dark';
  const theme = getTheme(isDark);
  const [time, setTime] = useState('');

  // 实时时间更新
  useEffect(() => {
    const timer = setInterval(() => {
      const now = new Date();
      setTime(now.toTimeString().split(' ')[0]);
    }, 1000);
    return () => clearInterval(timer);
  }, []);

  const columnStyle = {
    flex: 1,
    minWidth: '320px',
    display: 'flex',
    flexDirection: 'column' as const,
    gap: '30px',
    padding: '0 20px',
  };

  const sectionHeader = {
    fontFamily: theme.mono,
    fontSize: '12px',
    fontWeight: 'bold',
    letterSpacing: '0.1em',
    paddingBottom: '10px',
    borderBottom: `2px solid ${theme.text}`,
    marginBottom: '20px',
    display: 'flex',
    justifyContent: 'space-between'
  };

  return (
    <div style={{ backgroundColor: theme.bg, minHeight: '100vh', color: theme.text, paddingBottom: '60px' }}>
      <style>{`
        .manual-item:hover { opacity: 0.6; }
        @media (max-width: 996px) { .main-grid { flex-direction: column !important; } }
      `}</style>

      {/* 0. 顶部状态栏 Header */}
      <header style={{
        maxWidth: '1200px', margin: '0 auto',
        display: 'flex', justifyContent: 'space-between',
        padding: '30px 20px',
        fontFamily: theme.mono, fontSize: '11px', opacity: 0.5
      }}>
        <div>[ Kvanai ] // 运维工程师工作记录</div>
        <div>[ 本地时间: {time || '00:00:00'} ]</div>
      </header>

      {/* 1x3 核心布局 */}
      <main className="main-grid" style={{
        maxWidth: '1200px', margin: '0 auto',
        display: 'flex',
        flexWrap: 'wrap',
        justifyContent: 'space-between',
      }}>

        {/* 第一列: 知识库 (KNOWLEDGE BASE) */}
        <div style={columnStyle}>
          <div style={sectionHeader}>
            <span>01 / 知识库</span>
            <span style={{ opacity: 0.3 }}>KNOWLEDGE</span>
          </div>

          <div style={{ display: 'flex', flexDirection: 'column', gap: '30px' }}>
            {/* 子模块: AI 助手 */}
            <section>
              <div style={{ display: 'flex', alignItems: 'center', marginBottom: '10px' }}>
                <Icon color={isDark ? theme.subText : '#8250df'} d="M12 2L2 7l10 5 10-5-10-5zM2 17l10 5 10-5M2 12l10 5 10-5" />
                <span style={{ fontWeight: 600, fontSize: '14px', opacity: 0.9 }}>OpenClaw AI 助手</span>
              </div>
              <div style={{ paddingLeft: '30px' }}>
                <ManualItem theme={theme} to="/docs/kb-next/openclaw/openclaw-install" label="系统安装指南" />
                <ManualItem theme={theme} to="/docs/kb-next/openclaw/openclaw-command" label="指令提示词模板" />
                <ManualItem theme={theme} to="/docs/kb-next/openclaw/openclaw-plugin" label="智能体插件扩展" />
              </div>
            </section>

            {/* 子模块: NAS 玩法 */}
            <section>
              <div style={{ display: 'flex', alignItems: 'center', marginBottom: '10px' }}>
                <Icon color={isDark ? theme.subText : '#e36209'} d="M5 4h14a2 2 0 012 2v12a2 2 0 01-2 2H5a2 2 0 01-2-2V6a2 2 0 012-2zm0 5h14M5 14h14M9 4v16" />
                <span style={{ fontWeight: 600, fontSize: '14px', opacity: 0.9 }}>NAS 私有云存储</span>
              </div>
              <div style={{ paddingLeft: '30px' }}>
                <ManualItem theme={theme} to="/docs/kb-next/nas/getting-started" label="NAS 基础入门" />
              </div>
            </section>
          </div>
        </div>

        {/* 第二列: 基础设施 (INFRASTRUCTURE) */}
        <div style={{ ...columnStyle, borderLeft: `1px solid ${theme.border}`, borderRight: `1px solid ${theme.border}` }}>
          <div style={sectionHeader}>
            <span>02 / 基础设施</span>
            <span style={{ opacity: 0.3 }}>标准操作程序</span>
          </div>

          <div style={{ display: 'flex', flexDirection: 'column', gap: '25px' }}>
            <section>
              <div style={{ display: 'flex', alignItems: 'center', fontSize: '13px', fontWeight: 700, marginBottom: '8px', opacity: 0.8 }}>
                <Icon color={theme.accent} d="M21 16V8a2 2 0 00-1-1.73l-7-4a2 2 0 00-2 0l-7 4A2 2 0 003 8v8a2 2 0 001 1.73l7 4a2 2 0 002 0l7-4A2 2 0 0021 16z" />
                计算单元 (COMPUTE)
              </div>
              <div style={{ paddingLeft: '30px', fontFamily: theme.mono, fontSize: '12px', display: 'flex', flexDirection: 'column', gap: '4px', opacity: 0.6 }}>
                <Link to="/ops/linux" style={{ color: 'inherit' }}>&gt; Linux 内核调优</Link>
                <Link to="/ops/kubernetes" style={{ color: 'inherit' }}>&gt; Kubernetes 集群管理</Link>
              </div>
            </section>

            <section>
              <div style={{ display: 'flex', alignItems: 'center', fontSize: '13px', fontWeight: 700, marginBottom: '8px', opacity: 0.8 }}>
                <Icon color={theme.accent} d="M4 7v10c0 2 1.5 3 3.5 3h9c2 0 3.5-1 3.5-3V7M4 7c0-2 1.5-3 3.5-3h9c2 0 3.5 1 3.5 3" />
                数据持久化 (DATA)
              </div>
              <div style={{ paddingLeft: '30px', fontFamily: theme.mono, fontSize: '12px', display: 'flex', flexDirection: 'column', gap: '4px', opacity: 0.6 }}>
                <Link to="/ops/database" style={{ color: 'inherit' }}>&gt; MySQL 高可用 / Redis 缓存</Link>
                <Link to="/ops/message-queue" style={{ color: 'inherit' }}>&gt; 消息队列中间件</Link>
              </div>
            </section>

            <section>
              <div style={{ display: 'flex', alignItems: 'center', fontSize: '13px', fontWeight: 700, marginBottom: '8px', opacity: 0.8 }}>
                <Icon color={theme.accent} d="M18 20V10M12 20V4M6 20v-6" />
                可观测性 (OBSERVABILITY)
              </div>
              <div style={{ paddingLeft: '30px', fontFamily: theme.mono, fontSize: '12px', display: 'flex', flexDirection: 'column', gap: '4px', opacity: 0.6 }}>
                <Link to="/ops/prometheus" style={{ color: 'inherit' }}>&gt; Prometheus 监控 / Grafana 画板</Link>
              </div>
            </section>
          </div>
        </div>

        {/* 第三列: 自动化与日志 (OPERATIONS) */}
        <div style={columnStyle}>
          <div style={sectionHeader}>
            <span>03 / 自动化与日志</span>
            <span style={{ opacity: 0.3 }}>运行记录</span>
          </div>

          <div style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>
            <section>
              <ManualItem theme={theme} to="/automation/devops/gitlab/gitlab-install" label="CI/CD 流水线标准" type="square" dotColor="#cf222e" />
              <ManualItem theme={theme} to="/automation/shell/one-liners" label="常用 Shell 脚本片段" type="square" dotColor="#326ce5" />
              <ManualItem theme={theme} to="/automation/python/python-script" label="Python 自动化工程" type="square" dotColor="#e3b341" />
            </section>

            <div style={{ marginTop: '20px', padding: '15px', border: `1px dashed ${theme.border}`, borderRadius: '4px' }}>
              <div style={{ fontFamily: theme.mono, fontSize: '11px', opacity: 0.4, marginBottom: '10px' }}>// 归档记录 ARCHIVE</div>
              <ManualItem theme={theme} to="/docs/journal/faultrecord" label="故障复盘记录" type="square" dotColor="#586069" />
              <ManualItem theme={theme} to="/docs/journal/opstools" label="常用工具清单" type="square" dotColor="#586069" />
              <ManualItem theme={theme} to="/nav" label="外部资源导航" type="square" dotColor="#586069" />
            </div>
          </div>
        </div>

      </main>

      <footer style={{
        maxWidth: '1200px', margin: '80px auto 0 auto',
        textAlign: 'center', opacity: 0.2,
        fontFamily: theme.mono, fontSize: '10px', letterSpacing: '0.2em'
      }}>
        始于 2026 // KVANAI // 所有系统运行正常
      </footer>
    </div>
  );
};

export default function Home(): JSX.Element {
  return (
    <Layout title="Kvanai · 运维工程师工作记录" noFooter={true}>
      <DashboardContent />
    </Layout>
  );
}