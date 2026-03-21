import React from 'react'
import { Layout, DatePicker, Select } from 'antd'
import dayjs from 'dayjs'

const { Header } = Layout

const PORTFOLIO_OPTIONS = [
  { value: 'P-ALPHA', label: 'P-ALPHA' },
]

export default function AppHeader({ asOf, portfolioCode, onDateChange, onPortfolioChange }) {
  return (
    <Header
      style={{
        background: '#001529',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'space-between',
        padding: '0 24px',
        height: 56,
        lineHeight: '56px',
        flexShrink: 0,
      }}
    >
      <div
        style={{
          color: '#fff',
          fontSize: 18,
          fontWeight: 700,
          letterSpacing: '0.08em',
        }}
      >
        IBOR AI ANALYST
      </div>
      <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
        <DatePicker
          defaultValue={dayjs('2026-03-20')}
          format="YYYY-MM-DD"
          value={asOf ? dayjs(asOf) : null}
          onChange={(date) => {
            if (date) onDateChange(date.format('YYYY-MM-DD'))
          }}
          style={{ width: 150 }}
          allowClear={false}
        />
        <Select
          value={portfolioCode}
          options={PORTFOLIO_OPTIONS}
          onChange={onPortfolioChange}
          style={{ width: 130 }}
        />
      </div>
    </Header>
  )
}
