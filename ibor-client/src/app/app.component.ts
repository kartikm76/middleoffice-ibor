import { Component, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';

@Component({
  selector: 'app-root',
  standalone: true,
  imports: [CommonModule],
  templateUrl: './app.component.html'
})
export class AppComponent implements OnInit {
  year = new Date().getFullYear();

  // component references will be loaded lazily
  gridCmp: any = null;
  detailCmp: any = null;
  themeCmp: any = null;

  async ngOnInit() {
    // dynamically import portfolio components so they're not included in the initial bundle
    const grid = await import('./features/portfolios/portfolio-grid/portfolio-grid.component');
    this.gridCmp = grid.PortfolioGridComponent;
    const detail = await import('./features/portfolios/portfolio-detail/portfolio-detail.component');
    this.detailCmp = detail.PortfolioDetailComponent;

    // lazily import the theme toggle so header can render it
    const theme = await import('./shared/theme-toggle/theme-toggle.component');
    this.themeCmp = theme.ThemeToggleComponent;
  }
}
