import React from 'react'

const TYPE_COLORS = {
  EQUITY: '#4a9eff',
  BOND:   '#2ecc71',
  FUT:    '#f39c12',
  OPT:    '#9b59b6',
  FX:     '#1abc9c',
  INDEX:  '#e74c3c',
  OTHER:  '#7f8c8d',
}

function formatAum(value) {
  if (value == null || isNaN(value)) return '$0'
  if (Math.abs(value) >= 1_000_000) return `$${(value / 1_000_000).toFixed(1)}M`
  if (Math.abs(value) >= 1_000)     return `$${(value / 1_000).toFixed(1)}K`
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

  if (loading) {
    return (
      <div style={{ padding: '20px 0', color: 'var(--text-3)', fontSize: 13, textAlign: 'center' }}>
        Loading…
      </div>
    )
  }

  return (
    <div>
      {/* Portfolio ID */}
      <div className="sidebar-section">
        <div className="sidebar-label">Portfolio</div>
        <div className="sidebar-value">{portfolioId}</div>
      </div>

      {/* AUM */}
      <div className="sidebar-section">
        <div className="sidebar-label">Total AUM</div>
        <div className="sidebar-aum">{formatAum(totalAum)}</div>
      </div>

      {/* Dates */}
      <div className="sidebar-section">
        <div className="sidebar-label">As of</div>
        <div className="sidebar-value">{asOf || '—'}</div>
        <div className="sidebar-label" style={{ marginTop: '8px' }}>Snap Date</div>
        <div className="sidebar-value">{snapDate || '—'}</div>
      </div>

      <div className="sidebar-divider" />

      {/* Asset Mix */}
      <div className="sidebar-section">
        <div className="sidebar-label">Asset Mix</div>
        {assetMix.length === 0 && (
          <div style={{ fontSize: 13, color: 'var(--text-3)', marginTop: '4px' }}>No data</div>
        )}
        {assetMix.map(({ type, amount, pct }) => (
          <div key={type} className="asset-type">
            <div className="asset-type-name">
              <span style={{ color: 'var(--text-1)', fontWeight: 500 }}>{type}</span>
              <span style={{ color: 'var(--text-3)', fontSize: '12px' }}>{pct.toFixed(0)}%</span>
            </div>
            <div className="asset-type-bar">
              <div
                className="asset-type-fill"
                style={{ width: `${pct}%`, background: TYPE_COLORS[type] || TYPE_COLORS.OTHER }}
              />
            </div>
            <div style={{ fontSize: '12px', color: 'var(--text-3)', marginTop: '2px' }}>
              {formatAum(amount)}
            </div>
          </div>
        ))}
      </div>
    </div>
  )
}
