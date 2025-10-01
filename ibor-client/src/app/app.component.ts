import { Component } from '@angular/core';
import { PortfolioGridComponent } from './features/portfolios/portfolio-grid/portfolio-grid.component';
import { PortfolioDetailComponent } from './features/portfolios/portfolio-detail/portfolio-detail.component';
import { ThemeToggleComponent } from './shared/theme-toggle/theme-toggle.component';

@Component({
  selector: 'app-root',
  standalone: true,
  imports: [PortfolioGridComponent, PortfolioDetailComponent, ThemeToggleComponent],
  template: `
    <header class="app-header">
      <div class="title">IBOR Analytics</div>
      <app-theme-toggle></app-theme-toggle>
    </header>

    <main class="container">
      <section class="panel">
        <app-portfolio-grid></app-portfolio-grid>
      </section>

      <section class="panel">
        <app-portfolio-detail></app-portfolio-detail>
      </section>
    </main>
  `
})
export class AppComponent {}
