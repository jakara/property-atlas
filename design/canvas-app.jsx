/* Tianjin Property Atlas — design canvas
   17 artboards across 6 sections, all linked to the design doc. */

function CanvasApp() {
  const W = 1180, H = 820;  // iPad landscape exterior dimensions per design system spec

  // Helper: wrap any screen in an iPad-glass-style "frame" sized to artboard
  const F = (children) => children;

  return (
    <DesignCanvas
      title="天津置业地图 — Aetheris flagship"
      subtitle="iPad-first SwiftUI MVP · 17 屏覆盖完整流程 · 按设计系统 @aetheris 出稿，可直接交付 Claude Code 落地"
    >
      {/* ════════════════════════════════════════════════════════
          1 · ONBOARDING & BOOT
          ════════════════════════════════════════════════════════ */}
      <DCSection id="onboarding" title="1 · 首次启动 / 登录" subtitle="冷启动 → 数据导入 → iCloud Gate。地图始终可浏览，写入路径才需要 iCloud。">
        <DCArtboard id="seed" label="A1 · Seed 导入（全屏）" width={W} height={H}>
          <SeedImportScreen/>
        </DCArtboard>

        <DCArtboard id="icloud-gate" label="A2 · iCloud 未登录" width={W} height={H}>
          <MainScreen view={{ activeTab: 'visit', gate: 'icloud', syncStatus: 'offline' }}/>
        </DCArtboard>
      </DCSection>

      {/* ════════════════════════════════════════════════════════
          2 · MAIN MAP — three drawer tabs
          ════════════════════════════════════════════════════════ */}
      <DCSection id="main" title="2 · 主屏 · 三个 Tab" subtitle="61.8 / 38.2 黄金分割：左地图 / 右抽屉。Tab 切换是高频，搜索框跟随 Tab 上下文。">
        <DCArtboard id="main-visit" label="A3 · 看房 Tab（默认入口）" width={W} height={H}>
          <MainScreen view={{ activeTab: 'visit', selectedId: 'c2' }}/>
        </DCArtboard>

        <DCArtboard id="main-school" label="A4 · 学校 Tab" width={W} height={H}>
          <MainScreen view={{ activeTab: 'school', selectedId: null }}/>
        </DCArtboard>

        <DCArtboard id="main-zone" label="A5 · 区域 Tab（用户绘制）" width={W} height={H}>
          <MainScreen view={{ activeTab: 'zone', selectedId: null }}/>
        </DCArtboard>

        <DCArtboard id="layer-popover" label="A6 · 图层 popover 展开" width={W} height={H}>
          <MainScreen view={{ activeTab: 'visit', popover: 'layer', selectedId: 'c2' }}/>
        </DCArtboard>

        <DCArtboard id="filter-popover" label="A7 · 筛选 popover 展开" width={W} height={H}>
          <MainScreen view={{ activeTab: 'visit', popover: 'filter', selectedId: 'c2' }}/>
        </DCArtboard>
      </DCSection>

      {/* ════════════════════════════════════════════════════════
          3 · PROGRESSIVE DISCLOSURE — pin → popover → detail
          ════════════════════════════════════════════════════════ */}
      <DCSection id="detail" title="3 · 渐进披露 · pin → popover → 详情" subtitle="点 pin 弹小卡（5 个关键字段）；点小卡 → 进入完整详情。详情用 4 个 segment 分层，避免一屏堆叠。">
        <DCArtboard id="pin-popover" label="A8 · pin popover（轻量预览）" width={W} height={H}>
          <MainScreen view={{ activeTab: 'visit', selectedId: 'c2', pinPopoverId: 'c2' }}/>
        </DCArtboard>

        <DCArtboard id="compound-overview" label="A9 · Compound 详情 · 概览" width={W} height={H}>
          <MainScreen view={{ activeTab: 'visit', selectedId: 'c2', drawerMode: 'compoundDetail', compoundDetailTab: '概览' }}/>
        </DCArtboard>

        <DCArtboard id="compound-visits" label="A10 · Compound 详情 · 看房历史" width={W} height={H}>
          <MainScreen view={{ activeTab: 'visit', selectedId: 'c2', drawerMode: 'compoundDetail', compoundDetailTab: '看房' }}/>
        </DCArtboard>

        <DCArtboard id="compound-schools" label="A11 · Compound 详情 · 对口学校" width={W} height={H}>
          <MainScreen view={{ activeTab: 'visit', selectedId: 'c2', drawerMode: 'compoundDetail', compoundDetailTab: '学校' }}/>
        </DCArtboard>

        <DCArtboard id="school-detail" label="A12 · 学校详情" width={W} height={H}>
          <MainScreen view={{ activeTab: 'school', selectedId: null, drawerMode: 'schoolDetail', schoolId: 's2' }}/>
        </DCArtboard>
      </DCSection>

      {/* ════════════════════════════════════════════════════════
          4 · VISIT WIZARD (4 steps, photo mosaic background)
          ════════════════════════════════════════════════════════ */}
      <DCSection id="wizard" title="4 · 看房 Wizard · 4 步" subtitle="写入路径：尽量 chips / 滑块 / 步进 / 评星，不调起键盘。第 3 步起左侧地图淡出为已拍照片拼图，强化「现场记录」的语境。">
        <DCArtboard id="wiz-1" label="A13 · Step 1 · 基本信息" width={W} height={H}>
          <MainScreen view={{ activeTab: 'visit', selectedId: 'c2', wizardStep: 1 }}/>
        </DCArtboard>

        <DCArtboard id="wiz-2" label="A14 · Step 2 · 评分" width={W} height={H}>
          <MainScreen view={{ activeTab: 'visit', selectedId: 'c2', wizardStep: 2 }}/>
        </DCArtboard>

        <DCArtboard id="wiz-3" label="A15 · Step 3 · 标签 + 照片拼图背景" width={W} height={H}>
          <MainScreen view={{ activeTab: 'visit', selectedId: 'c2', wizardStep: 3, mapMode: 'mosaic' }}/>
        </DCArtboard>

        <DCArtboard id="wiz-4" label="A16 · Step 4 · 照片与备注" width={W} height={H}>
          <MainScreen view={{ activeTab: 'visit', selectedId: 'c2', wizardStep: 4, mapMode: 'mosaic' }}/>
        </DCArtboard>
      </DCSection>

      {/* ════════════════════════════════════════════════════════
          5 · POLYGON EDITOR
          ════════════════════════════════════════════════════════ */}
      <DCSection id="polygon" title="5 · PolygonEditor · 用户私有区域" subtitle="写 UserArea（私有），不动 pub_*。Phase 1 是手工 + Apple Pencil；Phase 1.5 加道路吸附；Phase 2 加 Overpass 围合。">
        <DCArtboard id="polygon-editor" label="A17 · 绘制中（顶点 + 边中点 + 操作栏）" width={W} height={H}>
          <PolygonEditorScreen mode="tap"/>
        </DCArtboard>
      </DCSection>

      {/* ════════════════════════════════════════════════════════
          6 · STATES & SETTINGS
          ════════════════════════════════════════════════════════ */}
      <DCSection id="states" title="6 · 状态与设置" subtitle="空态、错误态、设置都收口在抽屉里，地图永远不被遮蔽 — 这是 map-class app 的「非协商」边界。">
        <DCArtboard id="settings" label="A18 · 设置（地图样式 / iCloud 用量 / 数据）" width={W} height={H}>
          <MainScreen view={{ activeTab: 'visit', selectedId: null, drawerMode: 'settings' }}/>
        </DCArtboard>

        <DCArtboard id="empty-visits" label="A19 · 空态 · 没有看房记录" width={W} height={H}>
          <MainScreen view={{ activeTab: 'visit', selectedId: null, emptyState: 'no-visits' }}/>
        </DCArtboard>

        <DCArtboard id="empty-search" label="A20 · 空态 · 搜索无结果" width={W} height={H}>
          <MainScreen view={{ activeTab: 'visit', selectedId: null, emptyState: 'no-search' }}/>
        </DCArtboard>

        <DCArtboard id="empty-filter" label="A21 · 空态 · 筛选过紧（智能建议）" width={W} height={H}>
          <MainScreen view={{ activeTab: 'visit', selectedId: null, emptyState: 'no-filter' }}/>
        </DCArtboard>

        <DCArtboard id="offline" label="A22 · 离线 banner + 地图离线 chip" width={W} height={H}>
          <MainScreen view={{ activeTab: 'visit', selectedId: 'c2', topBanner: 'offline', mapChip: 'offline', syncStatus: 'offline' }}/>
        </DCArtboard>

        <DCArtboard id="icloud-full" label="A23 · iCloud 容量告警 banner" width={W} height={H}>
          <MainScreen view={{ activeTab: 'visit', selectedId: 'c2', topBanner: 'icloud-full', syncStatus: 'warning' }}/>
        </DCArtboard>
      </DCSection>
    </DesignCanvas>
  );
}

ReactDOM.createRoot(document.getElementById('root')).render(<CanvasApp/>);
