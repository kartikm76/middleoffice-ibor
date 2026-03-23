import React from 'react'
import { DatePicker, Select } from 'antd'
import dayjs from 'dayjs'

const PORTFOLIO_OPTIONS = [
  { value: 'P-ALPHA', label: 'P-ALPHA' },
]

export default function ControlsBar({ asOf, portfolioCode, onDateChange, onPortfolioChange, onSubmit, loading }) {
  return (
    <div className="controls-bar">
      <div className="controls-group">
        <span className="controls-label">As of</span>
        <DatePicker
          value={asOf ? dayjs(asOf) : null}
          format="YYYY-MM-DD"
          onChange={(date) => { if (date) onDateChange(date.format('YYYY-MM-DD')) }}
          allowClear={false}
          style={{ width: 160, marginLeft: 12 }}
          size="small"
        />
      </div>

      <div className="controls-group">
        <span className="controls-label">Portfolio</span>
        <Select
          value={portfolioCode}
          options={PORTFOLIO_OPTIONS}
          onChange={onPortfolioChange}
          style={{ width: 140, marginLeft: 12 }}
          size="small"
        />
      </div>

      <button
        className="submit-btn"
        onClick={onSubmit}
        disabled={loading}
      >
        {loading ? 'Loading...' : 'Submit'}
      </button>
    </div>
  )
}
