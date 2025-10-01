/**
 * Models for RAG (Retrieval-Augmented Generation) API interactions
 * – used by rag-api.service.ts
 */

export interface RagHybridAskRequest {
  question: string;
  instrumentTicker: string;
  portfolioCodes?: string[];
  topK?: number;
}

export interface RagContextChunk {
  docId: string;
  title: string;
  sourceUri: string;
  author: string;
  updatedAt: string;
  chunkIdx: number;
  content: string;
}

export interface RagFacts {
  instrumentId: number;
  ticker: string;
  qty: number;
  side: string;
  marketValue: number;
  price: {
    priceLast: number;
    currency: string;
    priceTime: string;
  };
}

export interface RagHybridAnswerResponse {
  answer: string;
  facts: RagFacts;
  contexts: RagContextChunk[];
  asOf: string;
}

export interface RagIngestNoteRequest {
  title: string;
  author: string;
  text: string;
  instrumentTickers: string[];
  portfolioCodes: string[];
}
