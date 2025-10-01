import { ChangeDetectionStrategy, Component } from '@angular/core';
import { CommonModule } from '@angular/common';

@Component({
  selector: 'app-kpi-card',
  standalone: true,
  imports: [CommonModule],
  templateUrl: './kpi-card.component.html',
  styleUrls: ['./kpi-card.component.scss'],
  changeDetection: ChangeDetectionStrategy.OnPush
})
export class KpiCardComponent {

}
