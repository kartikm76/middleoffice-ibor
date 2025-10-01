import { ChangeDetectionStrategy, Component } from '@angular/core';
import { CommonModule } from '@angular/common';

@Component({
  selector: 'app-chart-stacked',
  standalone: true,
  imports: [CommonModule],
  templateUrl: './chart-stacked.component.html',
  styleUrls: ['./chart-stacked.component.scss'],
  changeDetection: ChangeDetectionStrategy.OnPush
})
export class ChartStackedComponent {

}
