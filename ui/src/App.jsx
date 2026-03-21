import React, { useState, useEffect, useCallback } from 'react'
import FilterBar from './components/FilterBar.jsx'
import PortfolioSnapshot from './components/PortfolioSnapshot.jsx'
import AiChat from './components/AiChat.jsx'
import DataGrid from './components/DataGrid.jsx'
import { fetchPositions } from './api/ibor.js'

const DEFAULT_AS_OF = '2026-03-20'
const DEFAULT_PORTFOLIO = 'P-ALPHA'

export default function App() {
  const [theme, setTheme] = useState(() => localStorage.getItem('ibor-theme') || 'dark')
  const [asOf, setAsOf] = useState(DEFAULT_AS_OF)
  const [portfolioCode, setPortfolioCode] = useState(DEFAULT_PORTFOLIO)
  const [positions, setPositions] = useState([])
  const [snapDate, setSnapDate] = useState(null)
  const [totalAum, setTotalAum] = useState(0)
  const [loading, setLoading] = useState(false)
  const [gridState, setGridState] = useState({ tab: 'positions', data: {} })
  const [useContext, setUseContext] = useState(false)

  useEffect(() => {
    document.documentElement.setAttribute('data-theme', theme)
    localStorage.setItem('ibor-theme', theme)
  }, [theme])

  const toggleTheme = () => setTheme(t => t === 'dark' ? 'light' : 'dark')

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

  function handleAiAnswer(answer) {
    const ibor = answer?.data?.ibor || {}
    let newTab = gridState.tab
    let newData = { ...gridState.data }

    if (ibor.positions) { newData.positions = ibor.positions; newTab = 'positions' }
    if (ibor.trades) { newData.trades = ibor.trades; if (!ibor.positions) newTab = 'trades' }
    if (ibor.prices) { newData.prices = ibor.prices; if (!ibor.positions && !ibor.trades) newTab = 'prices' }
    if (ibor.pnl) { newData.pnl = ibor.pnl; if (!ibor.positions && !ibor.trades && !ibor.prices) newTab = 'pnl' }

    setGridState({ tab: newTab, data: newData })
  }

  function handleTabChange(tab) {
    setGridState(prev => ({ ...prev, tab }))
  }

  return (
    <div className="app-root">
      <FilterBar
        asOf={asOf}
        portfolioCode={portfolioCode}
        onDateChange={setAsOf}
        onPortfolioChange={setPortfolioCode}
        theme={theme}
        onToggleTheme={toggleTheme}
      />

      <div className="content-area">
        {/* Left sidebar — composition */}
        <div className="sidebar">
          <PortfolioSnapshot
            positions={positions}
            totalAum={totalAum}
            snapDate={snapDate}
            asOf={asOf}
            portfolioCode={portfolioCode}
            loading={loading}
          />
        </div>

        {/* Main content (grid stacked on chat) */}
        <div className="main-content">
          <div className="grid-pane">
            <DataGrid
              gridState={gridState}
              onTabChange={handleTabChange}
              theme={theme}
            />
          </div>

          <div className="chat-pane">
            <AiChat
              onAnswer={handleAiAnswer}
              useContext={useContext}
              onContextChange={setUseContext}
              positions={positions}
            />
          </div>
        </div>
      </div>
    </div>
  )
}
