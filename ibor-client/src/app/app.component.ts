import { Component } from '@angular/core';
import { PortfolioGridComponent } from './features/portfolios/portfolio-grid/portfolio-grid.component';
import { PortfolioDetailComponent } from './features/portfolios/portfolio-detail/portfolio-detail.component';

@Component({
  selector: 'app-root',
  standalone: true,
  imports: [PortfolioGridComponent, PortfolioDetailComponent],
  template: `
    <app-portfolio-grid></app-portfolio-grid>
    <app-portfolio-detail></app-portfolio-detail>
  `
})
export class AppComponent {}
