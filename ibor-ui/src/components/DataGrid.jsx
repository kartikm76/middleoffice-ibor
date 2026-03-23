import React, { useMemo } from 'react'
import { Tabs, Row, Col } from 'antd'
import { AgGridReact } from 'ag-grid-react'
import 'ag-grid-community/styles/ag-grid.css'
import 'ag-grid-community/styles/ag-theme-alpine.css'

const usdFmt = (p) =>
  p.value != null
    ? new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD', minimumFractionDigits: 2, maximumFractionDigits: 2 }).format(p.value)
    : ''

const numFmt = (p) =>
  p.value != null ? new Intl.NumberFormat('en-US', { maximumFractionDigits: 0 }).format(p.value) : ''

function normalizePosition(p) {
  return {
    instrument: p.instrumentId || p.instrument || '',
    type:       p.instrumentType || p.type || '',
    qty:        p.netQty ?? p.quantity ?? 0,
    price:      p.price ?? 0,
    mktValue:   p.mktValue ?? p.marketValue ?? 0,
    currency:   p.currency || 'USD',
    source:     p.priceSource || 'BBG',
  }
}

function normalizeTrade(t) {
  return {
    tradeId:     t.tradeId || t.transactionId || t.id || '',
    date:        t.tradeDate || t.date || t.settleDate || '',
    action:      t.action || t.side || t.transactionType || '',
    quantity:    t.quantity || t.netQty || t.qty || 0,
    price:       t.price ?? 0,
    grossAmount: t.grossAmount ?? t.amount ?? t.notional ?? 0,
  }
}

function normalizePrice(pr) {
  return {
    date:     pr.priceDate || pr.date || '',
    price:    pr.closePrice ?? pr.price ?? 0,
    currency: pr.currency || 'USD',
  }
}

const POSITION_COLS = [
  { field: 'instrument', headerName: 'Instrument', sortable: true, filter: true, flex: 1.5, minWidth: 110 },
  { field: 'type',       headerName: 'Type',       sortable: true, width: 85 },
  { field: 'qty',        headerName: 'Qty',        type: 'numericColumn', valueFormatter: numFmt,  width: 95 },
  { field: 'price',      headerName: 'Price',      type: 'numericColumn', valueFormatter: usdFmt,  width: 110 },
  { field: 'mktValue',   headerName: 'Mkt Value',  type: 'numericColumn', valueFormatter: usdFmt,  flex: 1, minWidth: 110 },
  { field: 'currency',   headerName: 'CCY',        width: 70 },
]

const TRADE_COLS = [
  { field: 'tradeId',     headerName: 'Trade ID',  sortable: true, filter: true, flex: 1.5, minWidth: 110 },
  { field: 'date',        headerName: 'Date',      sortable: true, width: 100 },
  { field: 'action',      headerName: 'Action',    sortable: true, width: 85 },
  { field: 'quantity',    headerName: 'Qty',       type: 'numericColumn', valueFormatter: numFmt, width: 95 },
  { field: 'price',       headerName: 'Price',     type: 'numericColumn', valueFormatter: usdFmt, width: 110 },
  { field: 'grossAmount', headerName: 'Amount',    type: 'numericColumn', valueFormatter: usdFmt, flex: 1, minWidth: 110 },
]

const PRICE_COLS = [
  { field: 'date',     headerName: 'Date',     sortable: true, filter: true, flex: 1, minWidth: 110 },
  { field: 'price',    headerName: 'Price',    type: 'numericColumn', valueFormatter: usdFmt, flex: 1, minWidth: 110 },
  { field: 'currency', headerName: 'Currency', width: 90 },
]

function Grid({ columnDefs, rowData, theme }) {
  const defaultColDef = useMemo(() => ({ resizable: true, sortable: true }), [])
  const gridClass = theme === 'dark' ? 'ag-theme-alpine-dark' : 'ag-theme-alpine'

  // Use autoHeight for small datasets, normal for large
  const useAutoHeight = rowData.length > 0 && rowData.length <= 20

  return (
    <div className={gridClass} style={useAutoHeight ? { width: '100%' } : { height: '100%', width: '100%' }}>
      <AgGridReact
        columnDefs={columnDefs}
        rowData={rowData}
        defaultColDef={defaultColDef}
        rowHeight={30}
        headerHeight={36}
        suppressCellFocus
        domLayout={useAutoHeight ? 'autoHeight' : undefined}
      />
    </div>
  )
}

function PnlPanel({ pnl }) {
  if (!pnl) {
    return (
      <div style={{ padding: 20, color: 'var(--text-3)', fontSize: 13 }}>
        No P&L data.
      </div>
    )
  }

  const delta = pnl.delta ?? (pnl.currentMarketValue - pnl.previousMarketValue)
  const deltaColor = delta >= 0 ? 'var(--green)' : 'var(--red)'
  const fmt = v => new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD', maximumFractionDigits: 0 }).format(v ?? 0)

  return (
    <div style={{ padding: 16 }}>
      <Row gutter={[12, 12]}>
        {[
          { label: 'Portfolio', value: pnl.portfolio || '—' },
          { label: 'Current MV', value: fmt(pnl.currentMarketValue), color: 'var(--accent)' },
          { label: 'Previous MV', value: fmt(pnl.previousMarketValue) },
          { label: 'Delta', value: fmt(delta), color: deltaColor, bold: true },
        ].map(({ label, value, color, bold }) => (
          <Col key={label} span={6}>
            <div style={{ padding: '10px 12px', background: 'var(--bg-surface)', borderRadius: '8px' }}>
              <div style={{ fontSize: 11, color: 'var(--text-3)', marginBottom: 4, fontWeight: 600 }}>{label}</div>
              <div style={{ fontSize: 14, fontWeight: bold ? 700 : 600, color: color || 'var(--text-1)' }}>{value}</div>
            </div>
          </Col>
        ))}
      </Row>
    </div>
  )
}

export default function DataGrid({ gridState, onTabChange, theme, selectedTickers }) {
  const { tab, data } = gridState

  const positionRows = useMemo(() => {
    const raw = data?.positions?.positions || data?.positions || []
    let rows = Array.isArray(raw) ? raw.map(normalizePosition) : []
    // Filter by selectedTickers if provided - check if instrument contains any selected ticker
    if (selectedTickers && selectedTickers.length > 0) {
      rows = rows.filter(p => {
        const inst = (p.instrument || '').toUpperCase()
        return selectedTickers.some(t => inst.includes(t))
      })
    }
    return rows
  }, [data, selectedTickers])

  const tradeRows = useMemo(() => {
    const raw = data?.trades?.transactions || data?.trades || []
    let rows = Array.isArray(raw) ? raw.map(normalizeTrade) : []
    // Filter by selectedTickers if provided
    if (selectedTickers && selectedTickers.length > 0) {
      rows = rows.filter(t => selectedTickers.includes((t.tradeId || t.instrument || '')?.toUpperCase()))
    }
    return rows
  }, [data, selectedTickers])

  const priceRows = useMemo(() => {
    const raw = data?.prices?.prices || data?.prices || []
    let rows = Array.isArray(raw) ? raw.map(normalizePrice) : []
    // Note: price rows typically don't have an instrument field in this structure
    return rows
  }, [data])

  const pnlData = data?.pnl || null

  const tabItems = [
    {
      key: 'positions',
      label: `Positions${positionRows.length ? ` (${positionRows.length})` : ''}`,
      children: <Grid columnDefs={POSITION_COLS} rowData={positionRows} theme={theme} />,
    },
    {
      key: 'trades',
      label: `Trades${tradeRows.length ? ` (${tradeRows.length})` : ''}`,
      children: <Grid columnDefs={TRADE_COLS} rowData={tradeRows} theme={theme} />,
    },
    {
      key: 'prices',
      label: `Prices${priceRows.length ? ` (${priceRows.length})` : ''}`,
      children: <Grid columnDefs={PRICE_COLS} rowData={priceRows} theme={theme} />,
    },
    {
      key: 'pnl',
      label: 'P&L',
      children: <PnlPanel pnl={pnlData} />,
    },
  ]

  return (
    <div className="grid-root">
      <Tabs
        activeKey={tab}
        onChange={onTabChange}
        items={tabItems}
        size="small"
        className="dark-tabs"
        style={{ height: '100%', display: 'flex', flexDirection: 'column' }}
      />
    </div>
  )
}
