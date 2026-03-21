import React, { useState, useRef, useEffect } from 'react'
import axios from 'axios'

const GREETING = "Ask me about positions, trades, P&L, and market data."

function ThinkingDots() {
  return (
    <span className="thinking-dots">
      <span /><span /><span />
    </span>
  )
}

function MessageBubble({ message }) {
  const isUser = message.role === 'user'

  // Format assistant message with proper structure
  let content = message.content
  if (!isUser && typeof content === 'string') {
    // Split into paragraphs for readability
    content = content.split('\n\n').map((para, i) => (
      <div key={i} style={{ marginBottom: i > 0 ? '8px' : '0' }}>
        {para}
      </div>
    ))
  }

  return (
    <div className={`chat-bubble-wrap ${isUser ? 'user' : 'assistant'}`}>
      <div className={`chat-bubble ${isUser ? 'user' : 'assistant'}`}>
        {message.thinking ? <ThinkingDots /> : content}
      </div>
    </div>
  )
}

export default function AiChat({ onAnswer, useContext, onContextChange, positions, totalAum }) {
  const [messages, setMessages] = useState([
    { id: 1, role: 'assistant', content: GREETING }
  ])
  const [input, setInput] = useState('')
  const [sending, setSending] = useState(false)
  const bottomRef = useRef(null)
  const textareaRef = useRef(null)
  const nextId = useRef(2)

  useEffect(() => {
    bottomRef.current?.scrollIntoView({ behavior: 'smooth' })
  }, [messages])

  useEffect(() => {
    textareaRef.current?.focus()
  }, [])

  async function handleSend() {
    const question = input.trim()
    if (!question || sending) return

    const userMsgId = nextId.current++
    const thinkingMsgId = nextId.current++

    setMessages(prev => [
      ...prev,
      { id: userMsgId, role: 'user', content: question },
      { id: thinkingMsgId, role: 'assistant', content: '', thinking: true },
    ])
    setInput('')
    setSending(true)

    try {
      const { data } = await axios.post(
        '/analyst/chat',
        { question },
        { headers: { 'Content-Type': 'application/json' } }
      )

      let summary = data.summary || '(No response)'

      // Format the response nicely
      if (!useContext) {
        // Without context: just the numbers
        summary = formatResponseDataOnly(summary, positions, totalAum)
      } else {
        // With context: keep full analyst narrative
        summary = formatResponseFull(summary)
      }

      setMessages(prev =>
        prev.map(m =>
          m.id === thinkingMsgId
            ? { ...m, content: summary, thinking: false }
            : m
        )
      )

      if (onAnswer) onAnswer(data)
    } catch (err) {
      const errMsg = err?.response?.data?.detail || err.message || 'An error occurred.'
      setMessages(prev =>
        prev.map(m =>
          m.id === thinkingMsgId
            ? { ...m, content: `Error: ${errMsg}`, thinking: false }
            : m
        )
      )
    } finally {
      setSending(false)
    }
  }

  function handleKeyDown(e) {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault()
      handleSend()
    }
  }

  return (
    <>
      <div className="chat-header">
        💬 AI Chat
      </div>

      <div className="context-checkbox">
        <input
          type="checkbox"
          id="context-toggle"
          checked={useContext}
          onChange={(e) => onContextChange(e.target.checked)}
        />
        <label htmlFor="context-toggle">
          Include market context
        </label>
      </div>

      <div className="chat-messages">
        {messages.map(msg => (
          <MessageBubble key={msg.id} message={msg} />
        ))}
        <div ref={bottomRef} />
      </div>

      <div className="chat-input-area">
        <div className="chat-input-row">
          <textarea
            ref={textareaRef}
            className="chat-input-field"
            value={input}
            onChange={e => setInput(e.target.value)}
            onKeyDown={handleKeyDown}
            placeholder="What do you want to know?"
            rows={1}
            disabled={sending}
          />
          <button
            className="chat-send-btn"
            onClick={handleSend}
            disabled={sending || !input.trim()}
          >
            {sending ? '…' : 'Send'}
          </button>
        </div>
      </div>
    </>
  )
}

/**
 * Format response with just numbers from DB (no market context)
 */
function formatResponseDataOnly(summary, positions, totalAum) {
  try {
    // Extract just the core numbers from the summary
    // Clean up JSON/markdown if present
    let text = summary.replace(/^```json\s*/i, '').replace(/```\s*$/, '')
    text = text.replace(/^```\s*/i, '').replace(/```\s*$/, '')

    // Build a clean instrument breakdown
    const posCount = positions?.length || 0
    const formattedAum = new Intl.NumberFormat('en-US', {
      style: 'currency',
      currency: 'USD',
      minimumFractionDigits: 0,
      maximumFractionDigits: 0,
    }).format(totalAum || 0)

    let response = `This portfolio has ${posCount} instruments with AUM of ${formattedAum}. Here is the breakdown:\n\n`

    // Group positions by type
    const byType = {}
    positions.forEach(p => {
      const type = p.instrumentType || p.type || 'OTHER'
      if (!byType[type]) byType[type] = []
      byType[type].push(p)
    })

    // Format each position
    Object.entries(byType).forEach(([type, items]) => {
      items.forEach(pos => {
        const instrument = pos.instrumentId || pos.instrument || 'Unknown'
        const qty = pos.netQty ?? pos.quantity ?? 0
        const price = pos.price ?? 0
        const mktValue = pos.mktValue ?? pos.marketValue ?? 0

        const formattedValue = new Intl.NumberFormat('en-US', {
          style: 'currency',
          currency: 'USD',
          minimumFractionDigits: 0,
          maximumFractionDigits: 0,
        }).format(mktValue)

        response += `${instrument}: ${Math.abs(qty).toLocaleString()} shares @ $${price.toFixed(2)} = ${formattedValue}\n`
      })
    })

    response += `\nSummary: ${text.slice(0, 300)}`

    return response
  } catch (err) {
    console.warn('Format error:', err)
    return summary
  }
}

/**
 * Format full analyst response (keep as-is, just clean JSON)
 */
function formatResponseFull(summary) {
  // Remove JSON/markdown wrappers if present
  let text = summary.replace(/^```json\s*/i, '').replace(/```\s*$/, '')
  text = text.replace(/^```\s*/i, '').replace(/```\s*$/, '')
  text = text.replace(/^[\s\[\{]*"?summary"?\s*:\s*\[?\s*/i, '')
  text = text.replace(/\]?\s*[\}\]]*$/, '')
  text = text.replace(/^"+/, '').replace(/"+$/, '')
  text = text.replace(/\\"/g, '"').replace(/\\n/g, '\n')
  return text.trim()
}
