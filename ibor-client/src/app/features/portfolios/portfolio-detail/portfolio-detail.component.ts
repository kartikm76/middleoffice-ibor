import { ChangeDetectionStrategy, Component } from '@angular/core';
import { CommonModule } from '@angular/common';

@Component({
  selector: 'app-portfolio-detail',
  standalone: true,
  imports: [CommonModule],
  templateUrl: './portfolio-detail.component.html',
  styleUrls: ['./portfolio-detail.component.scss'],
  changeDetection: ChangeDetectionStrategy.OnPush
})
export class PortfolioDetailComponent {

}
