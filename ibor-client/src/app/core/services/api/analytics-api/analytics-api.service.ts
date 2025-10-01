// Angular service for interacting with analytics-related API endpoints
import { Injectable, inject } from '@angular/core';
import { HttpClient, HttpParams } from '@angular/common/http';
import { Observable } from 'rxjs';
import {
  PortfolioReturnResponse,
  SecurityReturnResponse,
  BrinsonDailyResponse,
  BrinsonPeriodResponse,
} from './analytics-api.models';
import { toISODate } from '../../../../shared/utils/date-utils';

@Injectable({ providedIn: 'root' })
export class AnalyticsApiService {
  // Inject HttpClient for making HTTP requests
  private readonly http = inject(HttpClient);
  // Base URL for analytics API endpoints
  private readonly base = '/api/analytics';

  // --- String-based API methods ---

  // Fetch portfolio returns for a given portfolio and date range
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

  // Fetch security returns for a given portfolio as of a specific date
  getSecurityReturns(
    portfolioCode: string,
    asOfDate: string
  ): Observable<SecurityReturnResponse> {
    const params = new HttpParams()
      .set('portfolioCode', portfolioCode)
      .set('asOfDate', asOfDate);
    return this.http.get<SecurityReturnResponse>(`${this.base}/returns/securities`, { params });
  }

  // Fetch daily Brinson attribution for a portfolio and benchmark over a date range
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

  // Fetch period Brinson attribution for a portfolio and benchmark over a date range
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

  // --- Date-friendly wrapper methods ---

  // Wrapper: accepts Date objects for portfolio returns
  getPortfolioReturnsD(
    portfolioCode: string,
    startDate: Date,
    endDate: Date
  ): Observable<PortfolioReturnResponse> {
    return this.getPortfolioReturns(portfolioCode, toISODate(startDate), toISODate(endDate));
  }

  // Wrapper: accepts Date object for security returns
  getSecurityReturnsD(
    portfolioCode: string,
    asOfDate: Date
  ): Observable<SecurityReturnResponse> {
    return this.getSecurityReturns(portfolioCode, toISODate(asOfDate));
  }

  // Wrapper: accepts Date objects for daily Brinson attribution
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

  // Wrapper: accepts Date objects for period Brinson attribution
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
