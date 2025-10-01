// src/app/core/services/api/analytics-api.service.ts
import { Injectable, inject } from '@angular/core';
import { HttpClient, HttpParams } from '@angular/common/http';
import { Observable } from 'rxjs';
import {
  PortfolioReturnResponse,
  SecurityReturnResponse,
  BrinsonDailyResponse,
  BrinsonPeriodResponse,
} from './analytics-api.models'; // if you extracted interfaces; else keep inline
import { toISODate } from '../../../shared/utils/date-utils';

@Injectable({ providedIn: 'root' })
export class AnalyticsApiService {
  private readonly http = inject(HttpClient);
  private readonly base = '/api/analytics';

  // ---------- String-based (existing) ----------
  getPortfolioReturns(
    portfolioCode: string,
    startDate: string,
    endDate: string
  ): Observable<PortfolioReturnResponse> {
    const params = new HttpParams()
      .set('portfolioCode', portfolioCode)
      .set('startDate', startDate)
      .set('endDate', endDate);
    return this.http.get<PortfolioReturnResponse>(`${this.base}/returns/portfolio`, { params });
  }

  getSecurityReturns(
    portfolioCode: string,
    asOfDate: string
  ): Observable<SecurityReturnResponse> {
    const params = new HttpParams()
      .set('portfolioCode', portfolioCode)
      .set('asOfDate', asOfDate);
    return this.http.get<SecurityReturnResponse>(`${this.base}/returns/securities`, { params });
  }

  getBrinsonDaily(
    portfolioCode: string,
    benchmarkCode: string,
    startDate: string,
    endDate: string
  ): Observable<BrinsonDailyResponse> {
    const params = new HttpParams()
      .set('portfolioCode', portfolioCode)
      .set('benchmarkCode', benchmarkCode)
      .set('startDate', startDate)
      .set('endDate', endDate);
    return this.http.get<BrinsonDailyResponse>(`${this.base}/attribution/brinson/daily`, { params });
  }

  getBrinsonPeriod(
    portfolioCode: string,
    benchmarkCode: string,
    startDate: string,
    endDate: string
  ): Observable<BrinsonPeriodResponse> {
    const params = new HttpParams()
      .set('portfolioCode', portfolioCode)
      .set('benchmarkCode', benchmarkCode)
      .set('startDate', startDate)
      .set('endDate', endDate);
    return this.http.get<BrinsonPeriodResponse>(`${this.base}/attribution/brinson/period`, { params });
  }

  // ---------- Date-friendly wrappers (optional) ----------
  getPortfolioReturnsD(
    portfolioCode: string,
    startDate: Date,
    endDate: Date
  ): Observable<PortfolioReturnResponse> {
    return this.getPortfolioReturns(portfolioCode, toISODate(startDate), toISODate(endDate));
  }

  getSecurityReturnsD(
    portfolioCode: string,
    asOfDate: Date
  ): Observable<SecurityReturnResponse> {
    return this.getSecurityReturns(portfolioCode, toISODate(asOfDate));
  }

  getBrinsonDailyD(
    portfolioCode: string,
    benchmarkCode: string,
    startDate: Date,
    endDate: Date
  ): Observable<BrinsonDailyResponse> {
    return this.getBrinsonDaily(
      portfolioCode,
      benchmarkCode,
      toISODate(startDate),
      toISODate(endDate)
    );
  }

  getBrinsonPeriodD(
    portfolioCode: string,
    benchmarkCode: string,
    startDate: Date,
    endDate: Date
  ): Observable<BrinsonPeriodResponse> {
    return this.getBrinsonPeriod(
      portfolioCode,
      benchmarkCode,
      toISODate(startDate),
      toISODate(endDate)
    );
  }
}
