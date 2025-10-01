import { ChangeDetectionStrategy, Component } from '@angular/core';
import { CommonModule } from '@angular/common';

@Component({
  selector: 'app-chart-line',
  standalone: true,
  imports: [CommonModule],
  templateUrl: './chart-line.component.html',
  styleUrls: ['./chart-line.component.scss'],
  changeDetection: ChangeDetectionStrategy.OnPush
})
export class ChartLineComponent {

}
