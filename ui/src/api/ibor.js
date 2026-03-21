import axios from 'axios'

export async function fetchPositions(portfolioCode, asOf, page = 1, size = 500) {
  const { data } = await axios.get('/api/positions', {
    params: { portfolioCode, asOf, page, size }
  })
  return data
}
