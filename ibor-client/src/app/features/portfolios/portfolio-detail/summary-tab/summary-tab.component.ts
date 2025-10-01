import { Component, inject, signal, computed } from '@angular/core';
import { CommonModule } from '@angular/common';
import { toObservable } from '@angular/core/rxjs-interop';
import { of, Observable } from 'rxjs';
import { switchMap, map, startWith, catchError } from 'rxjs/operators';
import { AppStateService } from '../../../../core/services/app-state/app-state.service';
import { AnalyticsApiService } from '../../../../core/services/api/analytics-api/analytics-api.service';
import { PortfolioReturnResponse } from '../../../../core/services/api/analytics-api/analytics-api.models';

type Vm = {
  loading: boolean;
  error: string | null;
  data: PortfolioReturnResponse | null;
};

@Component({
  selector: 'app-summary-tab',
  standalone: true,
  imports: [CommonModule],
  templateUrl: './summary-tab.component.html',
})
export class SummaryTabComponent {
  private state = inject(AppStateService);
  private api = inject(AnalyticsApiService);

  private inputs = computed<{ pf: string; start: Date; end: Date } | null>(() => {
    const pf = this.state.selectedPortfolio();
    return pf ? { pf, start: this.state.start(), end: this.state.end() } : null;
  });

  vm = signal<Vm>({ loading: true, error: null, data: null });

  sub = (toObservable(this.inputs).pipe(
    switchMap(inp => {
      if (!inp) return of({ loading: false, error: null, data: null } as Vm);
      const { pf, start, end } = inp as { pf: string; start: Date; end: Date };
      return this.api.getPortfolioReturnsD(pf, start, end).pipe(
        map(data => ({ loading: false, error: null, data })),
        startWith({ loading: true, error: null, data: null } as Vm),
        catchError(e => of({ loading: false, error: e?.message ?? 'Failed', data: null } as Vm))
      );
    })
  ) as Observable<Vm>);

  subscription = this.sub.subscribe(v => this.vm.set(v));
}
