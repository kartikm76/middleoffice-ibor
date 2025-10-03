import { Component, inject, computed, ChangeDetectionStrategy } from '@angular/core';
import { CommonModule } from '@angular/common';
import { MatTabsModule } from '@angular/material/tabs';
import { MatCardModule } from '@angular/material/card';
import { AppStateService } from '../../../core/services/app-state/app-state.service';

// your tabs
import { SummaryTabComponent } from './summary-tab/summary-tab.component';
import { AttributionTabComponent } from './attribution-tab/attribution-tab.component';
import { SecuritiesTabComponent } from './securities-tab/securities-tab.component';
import { NotesTabComponent } from './notes-tab/notes-tab.component';
import { ExplainTabComponent } from './explain-tab/explain-tab.component';


@Component({
  selector: 'app-portfolio-detail',
  standalone: true,
  imports: [
    CommonModule,
    MatCardModule,
    MatTabsModule,
    // your tab components:
    SummaryTabComponent, AttributionTabComponent,
    SecuritiesTabComponent, NotesTabComponent, ExplainTabComponent
  ],
  templateUrl: './portfolio-detail.component.html',
  styleUrls: ['./portfolio-detail.component.scss'],
  changeDetection: ChangeDetectionStrategy.OnPush
})
export class PortfolioDetailComponent {
  private state = inject(AppStateService);
  selected = computed(() => this.state.selectedPortfolio());

  // control for tabs - keep in sync with mat-tab-group
  selectedIndex = 0;
}
