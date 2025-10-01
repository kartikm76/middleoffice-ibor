// src/app/core/services/app-state/app-state.service.ts
import { Injectable, signal, computed } from '@angular/core';
import { toISODate, fromISODate } from '../../../shared/utils/date-utils';

export type DateRange = { start: Date; end: Date };

@Injectable({ providedIn: 'root' })
export class AppStateService {
  // Defaults match your seed window
  readonly selectedPortfolio = signal<string | null>('ALPHA');
  readonly selectedBenchmark = signal<string>('SPX');
  readonly dateRange = signal<DateRange>({
    start: fromISODate('2025-09-24'),
    end:   fromISODate('2025-09-26'),
  });

  // Convenience (Date objects)
  readonly start = computed(() => this.dateRange().start);
  readonly end   = computed(() => this.dateRange().end);

  // API-ready strings (YYYY-MM-DD)
  readonly startDateStr = computed(() => toISODate(this.start()));
  readonly endDateStr   = computed(() => toISODate(this.end()));

  setPortfolio(code: string | null) { this.selectedPortfolio.set(code); }
  setBenchmark(code: string) { this.selectedBenchmark.set(code); }
  setDateRange(range: DateRange) { this.dateRange.set(range); }
}
