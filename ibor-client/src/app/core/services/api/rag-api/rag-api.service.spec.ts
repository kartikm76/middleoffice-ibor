import { TestBed } from '@angular/core/testing';

import { RagApiService } from './rag-api.service';

describe('RagApiService', () => {
  let service: RagApiService;

  beforeEach(() => {
    TestBed.configureTestingModule({});
    service = TestBed.inject(RagApiService);
  });

  it('should be created', () => {
    expect(service).toBeTruthy();
  });
});
