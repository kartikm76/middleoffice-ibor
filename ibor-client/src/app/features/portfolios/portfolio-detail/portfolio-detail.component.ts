import { Component, inject, computed } from '@angular/core';
import { CommonModule } from '@angular/common';
import { AppStateService } from '../../../core/services/app-state/app-state.service';

// import the tab components
import { SummaryTabComponent } from '../portfolio-detail/summary-tab/summary-tab.component';
import { AttributionTabComponent } from '../portfolio-detail/attribution-tab/attribution-tab.component';
import { SecuritiesTabComponent } from '../portfolio-detail/securities-tab/securities-tab.component';
import { NotesTabComponent } from '../portfolio-detail/notes-tab/notes-tab.component';
import { ExplainTabComponent } from '../portfolio-detail/explain-tab/explain-tab.component';

@Component({
  selector: 'app-portfolio-detail',
  standalone: true,
  imports: [
    CommonModule,
    SummaryTabComponent,
    AttributionTabComponent,
    SecuritiesTabComponent,
    NotesTabComponent,
    ExplainTabComponent
  ],
  templateUrl: './portfolio-detail.component.html'
})
export class PortfolioDetailComponent {
  private state = inject(AppStateService);
  selected = computed(() => this.state.selectedPortfolio());
}
