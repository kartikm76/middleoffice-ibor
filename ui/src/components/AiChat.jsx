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
  let content = message.content

  // If content is an array of bullets, render as bullets
  if (!isUser && Array.isArray(content)) {
    content = content.map((bullet, i) => (
      <div key={i} style={{ marginBottom: i < content.length - 1 ? '6px' : '0' }}>
        {bullet}
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

export default function AiChat({ onAnswer, useContext, onContextChange, positions }) {
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

      // If useContext is OFF, call summarize endpoint for compressed version
      if (!useContext && summary) {
        try {
          const sumResp = await axios.post('/analyst/summarize', { summary })
          let bulletPoints = sumResp.data?.summary || []

          // Clean up the response if it's wrapped in JSON or markdown
          if (Array.isArray(bulletPoints)) {
            bulletPoints = bulletPoints.map(b => cleanBullet(b))
          } else if (typeof bulletPoints === 'string') {
            bulletPoints = [cleanBullet(bulletPoints)]
          }

          summary = bulletPoints
        } catch (err) {
          console.warn('Summarize failed:', err)
          summary = [summary]
        }
      } else {
        // Keep full summary as plain text
        summary = [summary]
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
            ? { ...m, content: [errMsg], thinking: false }
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
 * Clean bullet point text by removing JSON/markdown wrappers
 */
function cleanBullet(text) {
  if (!text) return ''

  // Remove markdown code block markers
  text = text.replace(/^```json\s*/i, '').replace(/```\s*$/, '')
  text = text.replace(/^```\s*/i, '').replace(/```\s*$/, '')

  // Remove JSON quotes and array formatting
  text = text.replace(/^"/, '').replace(/",$/, '')
  text = text.replace(/\[\s*/, '').replace(/\s*\]/, '')

  // Remove "summary": [ prefix
  text = text.replace(/^[\s\[\{]*"?summary"?\s*:\s*\[\s*/i, '')
  text = text.replace(/\s*\]\s*[\}\]]*$/, '')

  // Decode escaped quotes and newlines
  text = text.replace(/\\"/g, '"').replace(/\\n/g, ' ')

  // Clean up extra quotes
  text = text.replace(/^"+/, '').replace(/"+$/, '')

  // Trim whitespace
  text = text.trim()

  // If starts with bullet, keep it; otherwise add one
  if (!text.startsWith('•')) {
    text = '• ' + text
  }

  return text
}
