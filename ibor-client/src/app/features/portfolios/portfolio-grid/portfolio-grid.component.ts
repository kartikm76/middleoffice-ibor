// src/app/features/portfolios/portfolio-grid/portfolio-grid.component.ts
// State Management:
// It injects AppStateService to manage the selected portfolio.
// Data:
// The all signal holds the list of portfolios.
// The q signal holds the current search query.
// Filtering:
// The filtered method returns portfolios matching the search query (by code or name).
// Search
// The onSearch method updates the search query when the user types in the input.
// Selection:
// The select method updates the selected portfolio in the app state when a row is clicked.
// Auto-selection:
// The init effect auto-selects the first portfolio if none is selected.
// Template:
// Renders a search box and a table. The table highlights the selected portfolio and updates on search or selection.


import { Component, inject, signal, effect } from '@angular/core';
import { CommonModule } from '@angular/common';
import { AppStateService } from '../../../core/services/app-state/app-state.service';

type Row = { code: string; name: string; benchmark: string; mv: number; twrr: number };

@Component({
  selector: 'app-portfolio-grid',
  standalone: true,
  imports: [CommonModule],
  templateUrl: './portfolio-grid.component.html',
  styleUrls: ['./portfolio-grid.component.scss'],
  // changeDetection already OnPush if you set it earlier
})
export class PortfolioGridComponent {
  state = inject(AppStateService);

  private all = signal<Row[]>([
    { code: 'ALPHA', name:'Global Growth', benchmark:'SPX', mv: 1200000, twrr: 0.23 },
    { code: 'BETA',  name:'Balanced Fund', benchmark:'SPX', mv:  950000, twrr: 0.12 },
  ]);
  private q = signal('');

  filtered = () =>
    this.all().filter(r => {
      const s = this.q().toLowerCase();
      return !s || r.code.toLowerCase().includes(s) || r.name.toLowerCase().includes(s);
    });

  onSearch(event: Event) {
    const value = (event.target as HTMLInputElement).value;
    this.q.set(value ?? '');
  }

  select(code: string) {
    if (this.state.selectedPortfolio() !== code) {
      this.state.setPortfolio(code);
    }
  }

  // Auto-select first row if none selected
  init = effect(() => {
    if (!this.state.selectedPortfolio() && this.all().length > 0) {
      this.state.setPortfolio(this.all()[0].code);
    }
  });
}
