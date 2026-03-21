import React, { useState, useRef, useEffect } from 'react'
import { Input, Button, Spin, Typography, Badge } from 'antd'
import axios from 'axios'

const { TextArea } = Input
const { Text } = Typography

const GREETING = "I have access to your IBOR positions, trades, prices, and P&L for portfolio P-ALPHA. I can also pull live market data and news for your equity holdings. Ask me anything."

function MessageBubble({ message }) {
  const isUser = message.role === 'user'
  const isThinking = message.thinking === true

  return (
    <div
      style={{
        display: 'flex',
        justifyContent: isUser ? 'flex-end' : 'flex-start',
        marginBottom: 12,
      }}
    >
      <div style={{ maxWidth: '75%' }}>
        <div
          style={{
            padding: '8px 14px',
            borderRadius: isUser ? '18px 18px 4px 18px' : '18px 18px 18px 4px',
            background: isUser ? '#1677ff' : '#f5f5f5',
            color: isUser ? '#fff' : '#1f1f1f',
            fontSize: 13,
            lineHeight: 1.6,
            whiteSpace: 'pre-wrap',
          }}
        >
          {isThinking ? (
            <span style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
              <Spin size="small" />
              <span style={{ color: '#999', fontSize: 12 }}>thinking…</span>
            </span>
          ) : (
            message.content
          )}
        </div>

        {/* Gaps / warnings */}
        {!isUser && message.gaps && message.gaps.length > 0 && (
          <div style={{ marginTop: 6, display: 'flex', flexWrap: 'wrap', gap: 4 }}>
            {message.gaps.map((gap, i) => (
              <Badge
                key={i}
                count={gap}
                style={{
                  backgroundColor: '#fa8c16',
                  fontSize: 10,
                  height: 18,
                  lineHeight: '18px',
                  padding: '0 6px',
                  borderRadius: 4,
                  maxWidth: 200,
                  overflow: 'hidden',
                  textOverflow: 'ellipsis',
                  whiteSpace: 'nowrap',
                }}
              />
            ))}
          </div>
        )}
      </div>
    </div>
  )
}

export default function AiChat({ onAnswer }) {
  const [messages, setMessages] = useState([
    { id: 1, role: 'assistant', content: GREETING, gaps: [] }
  ])
  const [input, setInput] = useState('')
  const [sending, setSending] = useState(false)
  const bottomRef = useRef(null)
  const nextId = useRef(2)

  useEffect(() => {
    bottomRef.current?.scrollIntoView({ behavior: 'smooth' })
  }, [messages])

  async function handleSend() {
    const question = input.trim()
    if (!question || sending) return

    const userMsgId = nextId.current++
    const thinkingMsgId = nextId.current++

    setMessages(prev => [
      ...prev,
      { id: userMsgId, role: 'user', content: question },
      { id: thinkingMsgId, role: 'assistant', content: '', thinking: true, gaps: [] },
    ])
    setInput('')
    setSending(true)

    try {
      const { data } = await axios.post(
        '/analyst/chat',
        { question },
        { headers: { 'Content-Type': 'application/json' } }
      )

      const summary = data.summary || '(No response)'
      const gaps = data.gaps || []

      setMessages(prev =>
        prev.map(m =>
          m.id === thinkingMsgId
            ? { ...m, content: summary, thinking: false, gaps }
            : m
        )
      )

      if (onAnswer) onAnswer(data)
    } catch (err) {
      const errMsg = err?.response?.data?.detail || err.message || 'An error occurred.'
      setMessages(prev =>
        prev.map(m =>
          m.id === thinkingMsgId
            ? { ...m, content: `Error: ${errMsg}`, thinking: false, gaps: [] }
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
    <div
      style={{
        display: 'flex',
        flexDirection: 'column',
        height: '100%',
        overflow: 'hidden',
      }}
    >
      {/* Header */}
      <div
        style={{
          padding: '10px 16px',
          borderBottom: '1px solid #e8e8e8',
          flexShrink: 0,
          background: '#fafafa',
        }}
      >
        <Text strong style={{ fontSize: 13, color: '#001529' }}>AI Analyst</Text>
      </div>

      {/* Messages area */}
      <div
        style={{
          flex: 1,
          overflowY: 'auto',
          padding: '16px',
        }}
      >
        {messages.map(msg => (
          <MessageBubble key={msg.id} message={msg} />
        ))}
        <div ref={bottomRef} />
      </div>

      {/* Input area */}
      <div
        style={{
          padding: '10px 16px',
          borderTop: '1px solid #e8e8e8',
          display: 'flex',
          gap: 8,
          flexShrink: 0,
          background: '#fff',
        }}
      >
        <TextArea
          value={input}
          onChange={e => setInput(e.target.value)}
          onKeyDown={handleKeyDown}
          placeholder="Ask about positions, trades, P&L, market data…"
          rows={2}
          style={{ resize: 'none', fontSize: 13 }}
          disabled={sending}
        />
        <Button
          type="primary"
          onClick={handleSend}
          loading={sending}
          disabled={!input.trim()}
          style={{ height: 'auto', alignSelf: 'stretch', minWidth: 72 }}
        >
          Send
        </Button>
      </div>
    </div>
  )
}
