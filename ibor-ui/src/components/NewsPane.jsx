import React, { useState, useEffect } from 'react'

function yahooUrl(ticker) {
  return ticker ? `https://finance.yahoo.com/quote/${ticker}/` : 'https://finance.yahoo.com/'
}

const MOCK_NEWS = [
  { title: 'Apple Reports Record Services Revenue in Q1', source: { name: 'Yahoo Finance' }, publishedAt: new Date().toISOString(), description: 'Apple Inc. services segment reaches all-time high as subscription growth accelerates across all categories.', ticker: 'AAPL' },
  { title: 'NVIDIA Surges on AI Data Center Demand', source: { name: 'Yahoo Finance' }, publishedAt: new Date(Date.now() - 3600000).toISOString(), description: 'NVIDIA shares climb as cloud providers expand AI infrastructure spending, driving GPU demand to new records.', ticker: 'NVDA' },
  { title: 'S&P 500 Hits New Highs on Tech Rally', source: { name: 'Yahoo Finance' }, publishedAt: new Date(Date.now() - 86400000).toISOString(), description: 'Technology stocks lead the market higher as investors rotate into growth names amid easing inflation concerns.', ticker: 'SPY' },
  { title: 'Microsoft Cloud Revenue Beats Expectations', source: { name: 'Yahoo Finance' }, publishedAt: new Date(Date.now() - 86400000 * 2).toISOString(), description: 'Azure growth of 35% YoY surpasses Street estimates as enterprise AI adoption gains momentum.', ticker: 'MSFT' },
  { title: 'Tesla Deliveries Top 500K in Quarter', source: { name: 'Yahoo Finance' }, publishedAt: new Date(Date.now() - 86400000 * 3).toISOString(), description: 'Tesla reports strong delivery numbers boosted by Model Y demand in China and Europe.', ticker: 'TSLA' },
  { title: 'Fed Signals Pause in Rate Hikes', source: { name: 'Yahoo Finance' }, publishedAt: new Date(Date.now() - 86400000 * 3).toISOString(), description: 'Federal Reserve officials suggest interest rate increases may be nearing an end as inflation cools to 2.4%.', ticker: null },
  { title: 'Meta Platforms Revenue Jumps 25% on Ad Rebound', source: { name: 'Yahoo Finance' }, publishedAt: new Date(Date.now() - 86400000 * 4).toISOString(), description: 'Advertising revenue recovery and Reels monetization drive double-digit growth at Meta.', ticker: 'META' },
  { title: 'JPMorgan Profits Rise on Higher Interest Income', source: { name: 'Yahoo Finance' }, publishedAt: new Date(Date.now() - 86400000 * 4).toISOString(), description: 'JPMorgan Chase reports 15% increase in net interest income amid elevated rate environment.', ticker: 'JPM' },
  { title: 'Amazon Web Services Growth Accelerates to 19%', source: { name: 'Yahoo Finance' }, publishedAt: new Date(Date.now() - 86400000 * 5).toISOString(), description: 'AWS reaccelerates growth as generative AI workloads drive new enterprise cloud commitments.', ticker: 'AMZN' },
  { title: 'Treasury Yields Decline on Softer Economic Data', source: { name: 'Yahoo Finance' }, publishedAt: new Date(Date.now() - 86400000 * 5).toISOString(), description: 'Bond markets rally as weaker employment and manufacturing data push yields lower across the curve.', ticker: null },
  { title: 'Goldman Sachs Trading Revenue Surges 30%', source: { name: 'Yahoo Finance' }, publishedAt: new Date(Date.now() - 86400000 * 6).toISOString(), description: 'Equities and FICC trading desks both beat estimates as market volatility fuels client activity.', ticker: 'GS' },
  { title: 'Energy Stocks Rally on Oil Price Surge', source: { name: 'Yahoo Finance' }, publishedAt: new Date(Date.now() - 86400000 * 7).toISOString(), description: 'Crude oil prices climb above $100 on OPEC+ production discipline and summer demand outlook.', ticker: 'XOM' },
]

export default function NewsPane({ selectedTickers = [], positions = [] }) {
  const [news, setNews] = useState(MOCK_NEWS)
  const [loading, setLoading] = useState(false)

  useEffect(() => {
    const fetchNews = async () => {
      setLoading(true)
      try {
        // Use NewsAPI to fetch news for the selected tickers
        const tickers = selectedTickers.length > 0
          ? selectedTickers
          : positions.slice(0, 5).map(p => p.instrumentId || p.instrument).filter(Boolean)

        if (tickers.length > 0) {
          const searchQuery = tickers.join(' OR ')
          const apiKey = 'demo'
          const url = `https://newsapi.org/v2/everything?q=${encodeURIComponent(searchQuery)}&sortBy=publishedAt&language=en&pageSize=10&apiKey=${apiKey}`

          const response = await fetch(url, { timeout: 5000 })
          const data = await response.json()

          if (data.articles && data.articles.length > 0) {
            setNews(data.articles.slice(0, 10))
          } else {
            setNews(MOCK_NEWS)
          }
        } else {
          setNews(MOCK_NEWS)
        }
      } catch (err) {
        console.warn('Failed to fetch news, using defaults:', err)
        setNews(MOCK_NEWS)
      } finally {
        setLoading(false)
      }
    }

    fetchNews()
  }, [selectedTickers, positions])

  return (
    <div style={{ height: '100%', display: 'flex', flexDirection: 'column', overflow: 'hidden' }}>
      <div style={{ fontSize: 13, fontWeight: 700, color: 'var(--text-2)', letterSpacing: '0.1em', textTransform: 'uppercase', padding: '12px 16px', borderBottom: '1px solid var(--border)', flexShrink: 0 }}>
        📰 Market News
      </div>

      <div style={{ flex: 1, overflowY: 'auto', padding: '12px 16px', scrollbarWidth: 'thin', scrollbarColor: 'var(--bg-surface) transparent' }}>
        {loading ? (
          <div style={{ fontSize: 14, color: 'var(--text-3)', padding: '12px 0' }}>
            Loading news...
          </div>
        ) : news.length === 0 ? (
          <div style={{ fontSize: 14, color: 'var(--text-3)', padding: '12px 0' }}>
            No news available
          </div>
        ) : (
          news.map((article, i) => (
            <div key={i} style={{ marginBottom: 16, paddingBottom: 12, borderBottom: '1px solid var(--border)' }}>
              <a
                href={article.ticker ? yahooUrl(article.ticker) : (article.url || 'https://finance.yahoo.com/')}
                target="_blank"
                rel="noopener noreferrer"
                style={{ textDecoration: 'none', cursor: 'pointer' }}
              >
                <div style={{ fontSize: 15, fontWeight: 600, color: 'var(--accent)', marginBottom: 6, lineHeight: 1.4 }}>
                  {article.title}
                </div>
              </a>
              <div style={{ fontSize: 12, color: 'var(--text-3)', marginBottom: 4 }}>
                {article.source?.name || 'Yahoo Finance'} • {new Date(article.publishedAt).toLocaleDateString()}
                {article.ticker && <span style={{ marginLeft: 8, color: 'var(--accent)', fontWeight: 600 }}>${article.ticker}</span>}
              </div>
              {article.description && (
                <div style={{ fontSize: 14, color: 'var(--text-2)', lineHeight: 1.5 }}>
                  {article.description}
                </div>
              )}
            </div>
          ))
        )}
      </div>
    </div>
  )
}
