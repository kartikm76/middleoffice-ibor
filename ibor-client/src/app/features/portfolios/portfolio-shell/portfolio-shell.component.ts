import { ChangeDetectionStrategy, Component } from '@angular/core';
import { CommonModule } from '@angular/common';
import {PortfolioGridComponent} from "../portfolio-grid/portfolio-grid.component";
import {SummaryTabComponent} from "../portfolio-detail/summary-tab/summary-tab.component";

@Component({
  selector: 'app-portfolio-shell',
  standalone: true,
  imports: [CommonModule, PortfolioGridComponent, SummaryTabComponent],
  templateUrl: './portfolio-shell.component.html',
  styleUrls: ['./portfolio-shell.component.scss'],
  changeDetection: ChangeDetectionStrategy.OnPush
})
export class PortfolioShellComponent {

}
