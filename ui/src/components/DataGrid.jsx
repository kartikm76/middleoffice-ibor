import React, { useMemo } from 'react'
import { Tabs, Statistic, Row, Col, Card } from 'antd'
import { AgGridReact } from 'ag-grid-react'
import 'ag-grid-community/styles/ag-grid.css'
import 'ag-grid-community/styles/ag-theme-alpine.css'

const GRID_HEIGHT = 276 // 320px panel - ~44px tabs header

const usdFormatter = (p) =>
  p.value != null
    ? new Intl.NumberFormat('en-US', {
        style: 'currency',
        currency: 'USD',
        minimumFractionDigits: 2,
        maximumFractionDigits: 2,
      }).format(p.value)
    : ''

const numberFormatter = (p) =>
  p.value != null
    ? new Intl.NumberFormat('en-US', { maximumFractionDigits: 0 }).format(p.value)
    : ''

// ---- Normalizers ----

function normalizePosition(p) {
  return {
    instrument: p.instrumentId || p.instrument || '',
    type: p.instrumentType || p.type || '',
    qty: p.netQty ?? p.quantity ?? 0,
    price: p.price ?? 0,
    mktValue: p.mktValue ?? p.marketValue ?? 0,
    currency: p.currency || 'USD',
    priceSource: p.priceSource || 'BBG',
    snapDate: p.snapDate || '',
  }
}

function normalizeTrade(t) {
  return {
    tradeId: t.tradeId || t.transactionId || t.id || '',
    date: t.tradeDate || t.date || t.settleDate || '',
    action: t.action || t.side || t.transactionType || '',
    quantity: t.quantity || t.netQty || t.qty || 0,
    price: t.price ?? 0,
    grossAmount: t.grossAmount ?? t.amount ?? t.notional ?? 0,
  }
}

function normalizePrice(pr) {
  return {
    date: pr.priceDate || pr.date || '',
    price: pr.closePrice ?? pr.price ?? 0,
    currency: pr.currency || 'USD',
  }
}

// ---- Column Defs ----

const POSITION_COLS = [
  { field: 'instrument', headerName: 'Instrument', sortable: true, filter: true, minWidth: 120 },
  { field: 'type', headerName: 'Type', sortable: true, filter: true, width: 90 },
  { field: 'qty', headerName: 'Quantity', type: 'numericColumn', valueFormatter: numberFormatter, width: 110 },
  { field: 'price', headerName: 'Price', type: 'numericColumn', valueFormatter: usdFormatter, width: 110 },
  { field: 'mktValue', headerName: 'Mkt Value', type: 'numericColumn', valueFormatter: usdFormatter, width: 130 },
  { field: 'currency', headerName: 'Currency', width: 90 },
  { field: 'priceSource', headerName: 'Source', width: 90 },
  { field: 'snapDate', headerName: 'Snap Date', width: 110 },
]

const TRADE_COLS = [
  { field: 'tradeId', headerName: 'Trade ID', sortable: true, filter: true, minWidth: 120 },
  { field: 'date', headerName: 'Date', sortable: true, width: 110 },
  { field: 'action', headerName: 'Action', sortable: true, width: 90 },
  { field: 'quantity', headerName: 'Quantity', type: 'numericColumn', valueFormatter: numberFormatter, width: 110 },
  { field: 'price', headerName: 'Price', type: 'numericColumn', valueFormatter: usdFormatter, width: 110 },
  { field: 'grossAmount', headerName: 'Gross Amount', type: 'numericColumn', valueFormatter: usdFormatter, width: 140 },
]

const PRICE_COLS = [
  { field: 'date', headerName: 'Date', sortable: true, filter: true, width: 120 },
  { field: 'price', headerName: 'Price', type: 'numericColumn', valueFormatter: usdFormatter, width: 130 },
  { field: 'currency', headerName: 'Currency', width: 100 },
]

// ---- Grid wrapper ----

function Grid({ columnDefs, rowData }) {
  const defaultColDef = useMemo(
    () => ({ resizable: true, sortable: true, suppressMovable: false }),
    []
  )

  return (
    <div
      className="ag-theme-alpine"
      style={{ height: GRID_HEIGHT, width: '100%' }}
    >
      <AgGridReact
        columnDefs={columnDefs}
        rowData={rowData}
        defaultColDef={defaultColDef}
        rowHeight={32}
        headerHeight={36}
        pagination
        paginationPageSize={20}
        suppressCellFocus
      />
    </div>
  )
}

// ---- P&L Card ----

function PnlPanel({ pnl }) {
  if (!pnl) {
    return (
      <div style={{ padding: 24, color: '#999', fontSize: 13 }}>
        No P&L data available. Ask the AI analyst for P&L.
      </div>
    )
  }

  const delta = pnl.delta ?? (pnl.currentMarketValue - pnl.previousMarketValue)
  const deltaColor = delta >= 0 ? '#52c41a' : '#ff4d4f'

  return (
    <div style={{ padding: 16 }}>
      <Row gutter={[16, 16]}>
        <Col span={8}>
          <Card size="small" style={{ background: '#fafafa' }}>
            <Statistic
              title="Portfolio"
              value={pnl.portfolio || pnl.portfolioCode || '—'}
              valueStyle={{ fontSize: 18, fontWeight: 700 }}
            />
          </Card>
        </Col>
        <Col span={8}>
          <Card size="small" style={{ background: '#fafafa' }}>
            <Statistic
              title="As Of"
              value={pnl.asOf || '—'}
              valueStyle={{ fontSize: 18 }}
            />
          </Card>
        </Col>
        <Col span={8}>
          <Card size="small" style={{ background: '#fafafa' }}>
            <Statistic
              title="Prior Date"
              value={pnl.prior || pnl.priorDate || '—'}
              valueStyle={{ fontSize: 18 }}
            />
          </Card>
        </Col>
        <Col span={8}>
          <Card size="small">
            <Statistic
              title="Current Market Value"
              value={pnl.currentMarketValue ?? 0}
              precision={2}
              prefix="$"
              valueStyle={{ fontSize: 18, color: '#1677ff' }}
            />
          </Card>
        </Col>
        <Col span={8}>
          <Card size="small">
            <Statistic
              title="Previous Market Value"
              value={pnl.previousMarketValue ?? 0}
              precision={2}
              prefix="$"
              valueStyle={{ fontSize: 18 }}
            />
          </Card>
        </Col>
        <Col span={8}>
          <Card size="small">
            <Statistic
              title="Delta (P&L)"
              value={delta ?? 0}
              precision={2}
              prefix="$"
              valueStyle={{ fontSize: 18, fontWeight: 700, color: deltaColor }}
            />
          </Card>
        </Col>
      </Row>
    </div>
  )
}

// ---- Main DataGrid component ----

export default function DataGrid({ gridState, onTabChange }) {
  const { tab, data } = gridState

  const positionRows = useMemo(() => {
    const raw = data?.positions?.positions || data?.positions || []
    return Array.isArray(raw) ? raw.map(normalizePosition) : []
  }, [data])

  const tradeRows = useMemo(() => {
    const raw = data?.trades?.transactions || data?.trades || []
    return Array.isArray(raw) ? raw.map(normalizeTrade) : []
  }, [data])

  const priceRows = useMemo(() => {
    const raw = data?.prices?.prices || data?.prices || []
    return Array.isArray(raw) ? raw.map(normalizePrice) : []
  }, [data])

  const pnlData = data?.pnl || null

  const tabItems = [
    {
      key: 'positions',
      label: `Positions${positionRows.length ? ` (${positionRows.length})` : ''}`,
      children: <Grid columnDefs={POSITION_COLS} rowData={positionRows} />,
    },
    {
      key: 'trades',
      label: `Trades${tradeRows.length ? ` (${tradeRows.length})` : ''}`,
      children: <Grid columnDefs={TRADE_COLS} rowData={tradeRows} />,
    },
    {
      key: 'prices',
      label: `Prices${priceRows.length ? ` (${priceRows.length})` : ''}`,
      children: <Grid columnDefs={PRICE_COLS} rowData={priceRows} />,
    },
    {
      key: 'pnl',
      label: 'P&L',
      children: <PnlPanel pnl={pnlData} />,
    },
  ]

  return (
    <div style={{ height: '100%', display: 'flex', flexDirection: 'column' }}>
      <Tabs
        activeKey={tab}
        onChange={onTabChange}
        items={tabItems}
        size="small"
        style={{ height: '100%' }}
        tabBarStyle={{ margin: 0, paddingLeft: 12, background: '#fafafa', borderBottom: '1px solid #e8e8e8' }}
      />
    </div>
  )
}
