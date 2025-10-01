// Model definitions for analytics-api.service
// TODO: Replace these placeholders with the actual response structures as needed

export interface PortfolioReturnResponse {
  // Example fields - update with real API response fields
  returns?: number[];
  dates?: string[];
  [key: string]: any;
}

export interface SecurityReturn {
  name: string;
  weight: number;
  returnPct: number;
  ticker: string;
  segment: string;
  // Add other fields as needed
}

export interface SecurityReturnResponse {
  securities?: SecurityReturn[];
  returns?: number[];
  [key: string]: any;
}

export interface BrinsonDailyResponse {
  // Example fields
  dailyAttribution?: any[];
  [key: string]: any;
}

export interface BrinsonPeriodResponse {
  // Example fields
  periodAttribution?: any[];
  [key: string]: any;
}
