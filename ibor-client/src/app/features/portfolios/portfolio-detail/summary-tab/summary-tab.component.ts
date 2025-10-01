// src/app/features/portfolios/portfolio-detail/summary-tab/summary-tab.component.ts
import { Component, computed, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { AppStateService } from '../../../../core/services/app-state/app-state.service';
import { AnalyticsApiService } from '../../../../core/services/api/analytics-api.service';
import { switchMap, of, catchError, startWith } from 'rxjs';
import { toObservable } from '@angular/core/rxjs-interop';

@Component({
  selector: 'app-summary-tab',
  standalone: true,
  imports: [CommonModule],
  template: `
  <ng-container *ngIf="vm() as m">
    <div *ngIf="m.loading">Loading…</div>
    <div *ngIf="m.error" class="err">Error: {{m.error}}</div>

    <div *ngIf="m.data">
      <div class="kpis">
        <div class="kpi"><div class="label">Period Return</div><div class="val">{{m.data.periodReturn | percent:'1.2-2'}}</div></div>
        <div class="kpi"><div class="label">Days</div><div class="val">{{m.data.dailyReturns.length}}</div></div>
      </div>
      <div class="list">
        <div *ngFor="let d of m.data.dailyReturns">
          {{d.asOfDate}} — {{d.twrr | percent:'1.2-2'}} (MV {{d.totalMVBase | number}})
        </div>
      </div>
    </div>
  </ng-container>
  `,
  styles: [`
    .kpis { display:flex; gap:1rem; margin-bottom:1rem; }
    .kpi { background:#fafafa; padding:1rem; border-radius:.5rem; }
    .label { color:#666; font-size:.85rem; }
    .val { font-size:1.2rem; font-weight:600; }
    .err { color:#b00020; }
  `]
})
export class SummaryTabComponent {
  private state = inject(AppStateService);
  private api = inject(AnalyticsApiService);

  // derive inputs from signals
  private inputs = computed(() => {
    const pf = this.state.selectedPortfolio();
    return pf ? { pf, start: this.state.startDate(), end: this.state.endDate() } : null;
  });

  // convert to observable and fetch
  vm = signal<{loading:boolean; error:string|null; data:any|null}>({loading:true, error:null, data:null});

  sub = toObservable(this.inputs).pipe(
    switchMap(inp => {
      if (!inp) return of({ loading:false, error:null, data:null });
      return this.api.getPortfolioReturns(inp.pf, inp.start, inp.end).pipe(
        map(data => ({ loading:false, error:null, data })),
        startWith({ loading:true, error:null, data:null }),
        catchError(e => of({ loading:false, error: e?.message ?? 'Failed', data:null }))
      );
    })
  ).subscribe(v => this.vm.set(v));
}
