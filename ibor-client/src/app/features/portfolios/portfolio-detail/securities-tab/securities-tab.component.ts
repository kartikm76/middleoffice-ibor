import { Component, inject, signal, computed } from '@angular/core';
import { CommonModule } from '@angular/common';
import { toObservable } from '@angular/core/rxjs-interop';
import { switchMap, map, startWith, catchError } from 'rxjs/operators';
import { of, Observable } from 'rxjs';
import { AppStateService } from '../../../../core/services/app-state/app-state.service';
import { AnalyticsApiService } from '../../../../core/services/api/analytics-api/analytics-api.service';
import { SecurityReturnResponse } from '../../../../core/services/api/analytics-api/analytics-api.models';

@Component({
  selector: 'app-securities-tab',
  standalone: true,
  imports: [CommonModule],
  templateUrl: './securities-tab.component.html'
})
export class SecuritiesTabComponent {
  // Inject application state and analytics API services
  private state = inject(AppStateService);
  private api   = inject(AnalyticsApiService);

  // Compute API call inputs based on selected portfolio and end date
  private inputs = computed<{ pf: string; asOf: Date } | null>(() => {
    const pf = this.state.selectedPortfolio();
    const asOf = this.state.end(); // Use end date as asOf
    return pf ? { pf, asOf } : null;
  });

  // Signal to hold the view model state: loading, error, and API data
  vm = signal<{loading:boolean; error:string|null; data:SecurityReturnResponse|null}>({
    loading:true, error:null, data:null
  });

  // Subscribe to input changes and fetch security returns accordingly
  sub = (toObservable(this.inputs).pipe(
    switchMap(inp => {
      if (!inp) return of({ loading: false, error: null, data: null } as { loading: boolean; error: string | null; data: SecurityReturnResponse | null });
      const { pf, asOf } = inp as { pf: string; asOf: Date };
      return this.api.getSecurityReturnsD(pf, asOf).pipe(
        map(data => ({ loading: false, error: null, data })),
        startWith({ loading: true, error: null, data: null } as { loading: boolean; error: string | null; data: SecurityReturnResponse | null }),
        catchError(e => of({ loading: false, error: e?.message ?? 'Failed', data: null } as { loading: boolean; error: string | null; data: SecurityReturnResponse | null }))
      );
    })
  ) as Observable<{ loading: boolean; error: string | null; data: SecurityReturnResponse | null }>);

  subscription = this.sub.subscribe(v => this.vm.set(v));
}
