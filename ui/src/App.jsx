import React, { useState, useEffect, useCallback } from 'react'
import { Layout } from 'antd'
import AppHeader from './components/AppHeader.jsx'
import PortfolioSnapshot from './components/PortfolioSnapshot.jsx'
import AiChat from './components/AiChat.jsx'
import DataGrid from './components/DataGrid.jsx'
import { fetchPositions } from './api/ibor.js'

const { Content } = Layout

const DEFAULT_AS_OF = '2026-03-20'
const DEFAULT_PORTFOLIO = 'P-ALPHA'

export default function App() {
  const [asOf, setAsOf] = useState(DEFAULT_AS_OF)
  const [portfolioCode, setPortfolioCode] = useState(DEFAULT_PORTFOLIO)
  const [positions, setPositions] = useState([])
  const [snapDate, setSnapDate] = useState(null)
  const [totalAum, setTotalAum] = useState(0)
  const [loading, setLoading] = useState(false)
  const [gridState, setGridState] = useState({ tab: 'positions', data: {} })

  const loadPositions = useCallback(async (portfolio, date) => {
    setLoading(true)
    try {
      const data = await fetchPositions(portfolio, date)
      const rows = Array.isArray(data) ? data : data?.positions || []
      setPositions(rows)
      const aum = rows.reduce((sum, p) => sum + (p.mktValue ?? p.marketValue ?? 0), 0)
      setTotalAum(aum)
      const firstSnapDate = rows[0]?.snapDate || null
      setSnapDate(firstSnapDate)
      // Pre-populate positions tab with Spring Boot data
      setGridState(prev => ({
        ...prev,
        tab: 'positions',
        data: { positions: rows },
      }))
    } catch (err) {
      console.error('Failed to load positions:', err)
      setPositions([])
      setTotalAum(0)
      setSnapDate(null)
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => {
    loadPositions(portfolioCode, asOf)
  }, [asOf, portfolioCode, loadPositions])

  function handleDateChange(newDate) {
    setAsOf(newDate)
  }

  function handlePortfolioChange(newPortfolio) {
    setPortfolioCode(newPortfolio)
  }

  function handleAiAnswer(answer) {
    const ibor = answer?.data?.ibor || {}

    let newTab = gridState.tab
    let newData = { ...gridState.data }

    if (ibor.positions) {
      newData.positions = ibor.positions
      newTab = 'positions'
    }
    if (ibor.trades) {
      newData.trades = ibor.trades
      if (!ibor.positions) newTab = 'trades'
    }
    if (ibor.prices) {
      newData.prices = ibor.prices
      if (!ibor.positions && !ibor.trades) newTab = 'prices'
    }
    if (ibor.pnl) {
      newData.pnl = ibor.pnl
      if (!ibor.positions && !ibor.trades && !ibor.prices) newTab = 'pnl'
    }

    setGridState({ tab: newTab, data: newData })
  }

  function handleTabChange(tab) {
    setGridState(prev => ({ ...prev, tab }))
  }

  return (
    <div className="app-root">
      {/* Header */}
      <AppHeader
        asOf={asOf}
        portfolioCode={portfolioCode}
        onDateChange={handleDateChange}
        onPortfolioChange={handlePortfolioChange}
      />

      {/* Middle row: snapshot + chat */}
      <div className="main-panels">
        <div className="left-panel">
          <PortfolioSnapshot
            positions={positions}
            totalAum={totalAum}
            snapDate={snapDate}
            asOf={asOf}
            portfolioCode={portfolioCode}
            loading={loading}
          />
        </div>
        <div className="right-panel">
          <AiChat onAnswer={handleAiAnswer} />
        </div>
      </div>

      {/* Bottom panel: tabbed data grid */}
      <div className="bottom-panel">
        <DataGrid gridState={gridState} onTabChange={handleTabChange} />
      </div>
    </div>
  )
}
