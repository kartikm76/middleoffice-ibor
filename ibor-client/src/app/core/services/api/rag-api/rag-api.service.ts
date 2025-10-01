// Angular service for interacting with the RAG (Retrieval-Augmented Generation) API
import { Injectable, inject } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';

// Request type for hybrid ask endpoint
export interface HybridAskRequest {
  question: string;
  instrumentTicker?: string | null;
  portfolioCodes?: string[] | null;
  topK?: number | null;
}

// Response type for hybrid answer endpoint
export interface HybridAnswerResponse {
  answer: string;
  facts?: unknown;
  contexts?: unknown[];
  // Additional fields like timestamp can be added as needed
}

@Injectable({ providedIn: 'root' })
export class RagApiService {
  // Inject HttpClient for making HTTP requests
  private http = inject(HttpClient);
  // Base URL for RAG API endpoints
  private base = '/api/rag';

  // Send a hybrid ask request to the API and return the answer
  askHybrid(req: HybridAskRequest): Observable<HybridAnswerResponse> {
    return this.http.post<HybridAnswerResponse>(`${this.base}/hybrid`, req);
  }
}
