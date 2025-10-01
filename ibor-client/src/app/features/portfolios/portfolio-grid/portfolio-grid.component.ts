import { Component, inject, signal, effect } from '@angular/core';
import { CommonModule } from '@angular/common';
import { MatTableModule } from '@angular/material/table';
import { AppStateService } from '../../../core/services/app-state/app-state.service';

type Row = { code: string; name: string; benchmark: string; mv: number; twrr: number };

@Component({
  selector: 'app-portfolio-grid',
  standalone: true,
  imports: [CommonModule, MatTableModule],
  templateUrl: './portfolio-grid.component.html',
  styleUrls: ['./portfolio-grid.component.scss']
})
export class PortfolioGridComponent {
  state = inject(AppStateService);
  displayedColumns = ['code','name','mv','twrr','benchmark'];

  private all = signal<Row[]>([
    { code: 'ALPHA', name:'Global Growth', benchmark:'SPX', mv: 1200000, twrr: 0.23 },
    { code: 'BETA',  name:'Balanced Fund', benchmark:'SPX', mv:  950000, twrr: 0.12 },
  ]);
  private q = signal('');

  data = () => this.all().filter(r => {
    const s = this.q().toLowerCase();
    return !s || r.code.toLowerCase().includes(s) || r.name.toLowerCase().includes(s);
  });

  onSearch(value: string) { this.q.set(value ?? ''); }
  select(code: string) { if (this.state.selectedPortfolio() !== code) this.state.setPortfolio(code); }

  init = effect(() => {
    if (!this.state.selectedPortfolio() && this.all().length > 0) this.state.setPortfolio(this.all()[0].code);
  });
}
