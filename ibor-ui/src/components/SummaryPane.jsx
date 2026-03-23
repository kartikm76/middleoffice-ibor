import React from 'react'

export default function SummaryPane({ positions, totalAum }) {
  const posCount = positions?.length || 0

  // Calculate by type
  const byType = {}
  let maxValue = 0
  positions?.forEach(p => {
    const type = p.instrumentType || p.type || 'OTHER'
    const val = Math.abs(p.mktValue ?? p.marketValue ?? 0)
    if (!byType[type]) byType[type] = { count: 0, value: 0 }
    byType[type].count += 1
    byType[type].value += val
    maxValue = Math.max(maxValue, val)
  })

  // Sort by value descending
  const sorted = Object.entries(byType).sort((a, b) => b[1].value - a[1].value)

  const formatValue = (v) => {
    if (v >= 1_000_000) return `$${(v / 1_000_000).toFixed(1)}M`
    if (v >= 1_000) return `$${(v / 1_000).toFixed(1)}K`
    return `$${v.toFixed(0)}`
  }

  return (
    <div style={{ height: '100%', display: 'flex', flexDirection: 'column' }}>
      <div style={{ fontSize: 12, fontWeight: 700, color: 'var(--text-2)', letterSpacing: '0.1em', marginBottom: 10, textTransform: 'uppercase' }}>
        📊 Data Summary
      </div>

      <div style={{ fontSize: 13, marginBottom: 12 }}>
        <div style={{ color: 'var(--text-3)', fontSize: 11, marginBottom: 2 }}>Total Positions</div>
        <div style={{ fontSize: 18, fontWeight: 700, color: 'var(--accent)' }}>
          {posCount}
        </div>
      </div>

      <div style={{ fontSize: 13, marginBottom: 12 }}>
        <div style={{ color: 'var(--text-3)', fontSize: 11, marginBottom: 2 }}>Total AUM</div>
        <div style={{ fontSize: 18, fontWeight: 700, color: 'var(--accent)' }}>
          {formatValue(totalAum || 0)}
        </div>
      </div>

      <div style={{ borderTop: '1px solid var(--border)', paddingTop: 10, marginTop: 10 }}>
        <div style={{ fontSize: 12, fontWeight: 700, color: 'var(--text-2)', letterSpacing: '0.05em', marginBottom: 8, textTransform: 'uppercase' }}>
          By Type
        </div>

        {sorted.map(([type, data]) => (
          <div key={type} style={{ marginBottom: 8 }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: 12, marginBottom: 2 }}>
              <span style={{ color: 'var(--text-1)', fontWeight: 500 }}>{type}</span>
              <span style={{ color: 'var(--text-3)' }}>{data.count}</span>
            </div>
            <div style={{ fontSize: 13, fontWeight: 600, color: 'var(--accent)' }}>
              {formatValue(data.value)}
            </div>
            <div style={{
              height: 4,
              background: 'var(--bg-surface)',
              borderRadius: 2,
              overflow: 'hidden',
              marginTop: 3,
            }}>
              <div style={{
                height: '100%',
                width: `${(data.value / (totalAum || 1)) * 100}%`,
                background: 'var(--accent)',
                borderRadius: 2,
              }} />
            </div>
          </div>
        ))}
      </div>
    </div>
  )
}
