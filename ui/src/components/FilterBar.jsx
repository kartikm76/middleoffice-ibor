import React from 'react'
import { DatePicker, Select } from 'antd'
import dayjs from 'dayjs'

const PORTFOLIO_OPTIONS = [
  { value: 'P-ALPHA', label: 'P-ALPHA' },
]

export default function FilterBar({ asOf, portfolioCode, onDateChange, onPortfolioChange, onSubmit, loading, theme, onToggleTheme }) {
  return (
    <div className="filter-bar">
      <div className="filter-bar-brand">
        <div className="filter-bar-brand-dot" />
        IBOR
      </div>

      <div className="filter-bar-group">
        <span className="filter-bar-label">As of</span>
        <DatePicker
          value={asOf ? dayjs(asOf) : null}
          format="YYYY-MM-DD"
          onChange={(date) => { if (date) onDateChange(date.format('YYYY-MM-DD')) }}
          allowClear={false}
          style={{ width: 150 }}
          size="small"
        />
      </div>

      <div className="filter-bar-group">
        <span className="filter-bar-label">Portfolio</span>
        <Select
          value={portfolioCode}
          options={PORTFOLIO_OPTIONS}
          onChange={onPortfolioChange}
          style={{ width: 130 }}
          size="small"
        />
      </div>

      <button className="submit-btn" onClick={onSubmit} disabled={loading}>
        {loading ? 'Loading...' : 'Submit'}
      </button>

      <div style={{ flex: 1 }} />

      <button className="theme-toggle" onClick={onToggleTheme} title="Toggle theme">
        {theme === 'dark' ? '☀️' : '🌙'}
      </button>
    </div>
  )
}
