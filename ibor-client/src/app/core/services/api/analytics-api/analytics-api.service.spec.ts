import { TestBed } from '@angular/core/testing';

import { AnalyticsApiService } from './analytics-api.service';

describe('AnalyticsApiService', () => {
  let service: AnalyticsApiService;

  beforeEach(() => {
    TestBed.configureTestingModule({});
    service = TestBed.inject(AnalyticsApiService);
  });

  it('should be created', () => {
    expect(service).toBeTruthy();
  });
});
