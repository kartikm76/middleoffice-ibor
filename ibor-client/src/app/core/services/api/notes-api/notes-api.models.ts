export interface IngestNoteRequest {
  title: string;
  author: string;
  text: string;
  instrumentTickers: string[];
  portfolioCodes: string[];
}
