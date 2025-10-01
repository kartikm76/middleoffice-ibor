// Angular service for interacting with the notes API
import { Injectable, inject } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';

// Request type for ingesting a note
export interface IngestNoteRequest {
  title: string;
  author: string;
  text: string;
  instrumentTickers: string[];
  portfolioCodes: string[];
}

@Injectable({ providedIn: 'root' })
export class NotesApiService {
  // Inject HttpClient for making HTTP requests
  private http = inject(HttpClient);
  // Base URL for notes API endpoints
  private base = '/api/notes';

  // Ingest a note by sending a POST request to the API
  ingest(req: IngestNoteRequest): Observable<Record<string, unknown>> {
    return this.http.post<Record<string, unknown>>(`${this.base}/ingest`, req);
  }
}
