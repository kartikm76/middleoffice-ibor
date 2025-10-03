// Angular and RxJS imports
import { Component, inject, signal, computed, ChangeDetectionStrategy } from '@angular/core';
import { CommonModule } from '@angular/common';
import { toObservable } from '@angular/core/rxjs-interop';
import { switchMap, map, catchError, of, combineLatest, tap, debounceTime, distinctUntilChanged } from 'rxjs';
import { AppStateService } from '../../../../core/services/app-state/app-state.service';
import { AnalyticsApiService } from '../../../../core/services/api/analytics-api/analytics-api.service';
import { BrinsonPeriodResponse, BrinsonDailyResponse } from '../../../../core/services/api/analytics-api/analytics-api.models';

// ViewModel type for component state
type Vm = {
  loading: boolean;
  error: string | null;
  period: BrinsonPeriodResponse | null;
  daily: BrinsonDailyResponse | null;
};

@Component({
  selector: 'app-attribution-tab',
  standalone: true,
  imports: [CommonModule],
  templateUrl: './attribution-tab.component.html',
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class AttributionTabComponent {
  // Inject application state and analytics API services
  private state = inject(AppStateService);
  private api   = inject(AnalyticsApiService);

  // Compute API call inputs based on selected portfolio, benchmark, and date range
  private inputs = computed(() => {
    const pf = this.state.selectedPortfolio();
    const bm = this.state.selectedBenchmark();
    return pf ? { pf, bm, start: this.state.start(), end: this.state.end() } : null;
  });

  // Signal to hold the view model state: loading, error, and API data
  vm = signal<Vm>({ loading:true, error:null, period:null, daily:null });

  // Subscribe to input changes and fetch attribution data accordingly
  sub = toObservable(this.inputs).pipe(
    debounceTime(120),
    distinctUntilChanged((a, b) => {
      if (a === b) return true;
      if (!a || !b) return false;
      return a.pf === b.pf && a.bm === b.bm && a.start.getTime() === b.start.getTime() && a.end.getTime() === b.end.getTime();
    }),
    switchMap(inp => {
      if (!inp) return of({ loading:false, error:null, period:this.vm().period, daily:this.vm().daily });
      // Cast inp to the expected type
      const { pf, bm, start, end } = inp as { pf: string; bm: string; start: Date; end: Date };
      // set loading without clearing existing content
      this.vm.update(v => ({ ...v, loading: true, error: null }));
      // Call both period and daily attribution APIs in parallel
      const period$ = this.api.getBrinsonPeriodD(pf, bm, start, end);
      const daily$  = this.api.getBrinsonDailyD(pf, bm, start, end);
      return combineLatest([period$, daily$]).pipe(
        tap(() => {/* keep prior content while loading */}),
        map(([period, daily]) => ({ loading:false, error:null, period, daily })),
        catchError(e => of({ loading:false, error: e?.message ?? 'Failed', period:this.vm().period, daily:this.vm().daily }))
      );
    })
  ).subscribe(v => this.vm.set(v)); // Update the signal with the latest state
}
