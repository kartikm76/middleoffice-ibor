import React from 'react'
import { Divider, Progress, Spin, Badge, Typography } from 'antd'

const { Text } = Typography

const TYPE_COLORS = {
  EQUITY: '#1677ff',
  BOND: '#52c41a',
  FUT: '#fa8c16',
  OPT: '#722ed1',
  FX: '#13c2c2',
  INDEX: '#eb2f96',
  OTHER: '#8c8c8c',
}

function formatAum(value) {
  if (value == null || isNaN(value)) return '$0'
  if (Math.abs(value) >= 1_000_000) {
    return `$${(value / 1_000_000).toFixed(1)}M`
  }
  if (Math.abs(value) >= 1_000) {
    return `$${(value / 1_000).toFixed(1)}K`
  }
  return new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD', maximumFractionDigits: 0 }).format(value)
}

function computeAssetMix(positions) {
  const totals = {}
  let grand = 0
  for (const p of positions) {
    const type = p.instrumentType || p.type || 'OTHER'
    const val = Math.abs(p.mktValue ?? p.marketValue ?? 0)
    totals[type] = (totals[type] || 0) + val
    grand += val
  }
  if (grand === 0) return []
  return Object.entries(totals)
    .map(([type, amount]) => ({ type, amount, pct: (amount / grand) * 100 }))
    .sort((a, b) => b.amount - a.amount)
}

export default function PortfolioSnapshot({ positions, totalAum, snapDate, asOf, portfolioCode, loading }) {
  const assetMix = computeAssetMix(positions)
  const portfolioId = (positions[0] && (positions[0].portfolioId || positions[0].portfolio)) || portfolioCode || 'P-ALPHA'
  const isStale = snapDate && asOf && snapDate !== asOf

  return (
    <Spin spinning={loading}>
      <div style={{ padding: '4px 0' }}>
        {/* Portfolio label */}
        <div style={{ marginBottom: 12 }}>
          <Text type="secondary" style={{ fontSize: 11, textTransform: 'uppercase', letterSpacing: '0.06em' }}>
            Portfolio
          </Text>
          <div style={{ fontSize: 20, fontWeight: 700, color: '#001529', lineHeight: 1.2 }}>
            {portfolioId}
          </div>
        </div>

        {/* AUM */}
        <div style={{ marginBottom: 10 }}>
          <Text type="secondary" style={{ fontSize: 11, textTransform: 'uppercase', letterSpacing: '0.06em' }}>
            AUM
          </Text>
          <div style={{ fontSize: 24, fontWeight: 700, color: '#1677ff' }}>
            {formatAum(totalAum)}
          </div>
        </div>

        {/* Snap date */}
        <div style={{ marginBottom: 4 }}>
          <Text type="secondary" style={{ fontSize: 11, textTransform: 'uppercase', letterSpacing: '0.06em' }}>
            Snap Date
          </Text>
          <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginTop: 2 }}>
            <Text style={{ fontSize: 13 }}>{snapDate || '—'}</Text>
            {isStale && (
              <Badge
                count="STALE"
                style={{
                  backgroundColor: '#fa8c16',
                  fontSize: 9,
                  height: 16,
                  lineHeight: '16px',
                  padding: '0 5px',
                  borderRadius: 3,
                }}
              />
            )}
          </div>
        </div>

        {/* As of */}
        <div style={{ marginBottom: 8 }}>
          <Text type="secondary" style={{ fontSize: 11, textTransform: 'uppercase', letterSpacing: '0.06em' }}>
            As Of
          </Text>
          <div>
            <Text style={{ fontSize: 13 }}>{asOf || '—'}</Text>
          </div>
        </div>

        <Divider style={{ margin: '12px 0' }} />

        {/* Asset Mix */}
        <div style={{ marginBottom: 8 }}>
          <Text
            type="secondary"
            style={{ fontSize: 11, textTransform: 'uppercase', letterSpacing: '0.06em', display: 'block', marginBottom: 10 }}
          >
            Asset Mix
          </Text>
          {assetMix.length === 0 && (
            <Text type="secondary" style={{ fontSize: 12 }}>No position data</Text>
          )}
          {assetMix.map(({ type, amount, pct }) => (
            <div key={type} style={{ marginBottom: 10 }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 3 }}>
                <Text style={{ fontSize: 11, fontWeight: 600 }}>{type}</Text>
                <Text style={{ fontSize: 11, color: '#666' }}>
                  {pct.toFixed(1)}% &nbsp; {formatAum(amount)}
                </Text>
              </div>
              <Progress
                percent={Math.round(pct)}
                showInfo={false}
                strokeColor={TYPE_COLORS[type] || TYPE_COLORS.OTHER}
                trailColor="#f0f0f0"
                size="small"
                style={{ margin: 0 }}
              />
            </div>
          ))}
        </div>

        <Divider style={{ margin: '12px 0' }} />

        {/* Data range */}
        <div>
          <Text type="secondary" style={{ fontSize: 11, textTransform: 'uppercase', letterSpacing: '0.06em' }}>
            Data Range
          </Text>
          <div>
            <Text style={{ fontSize: 12, color: '#444' }}>2025-01-02 → 2026-03-20</Text>
          </div>
        </div>
      </div>
    </Spin>
  )
}
