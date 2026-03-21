import React from 'react'

export default function FilterBar({ theme, onToggleTheme }) {
  return (
    <div className="filter-bar">
      <div className="filter-bar-brand">
        <div className="filter-bar-brand-dot" />
        IBOR
      </div>

      <div style={{ flex: 1 }} />

      <button className="theme-toggle" onClick={onToggleTheme} title="Toggle theme">
        {theme === 'dark' ? '☀️' : '🌙'}
      </button>
    </div>
  )
}
