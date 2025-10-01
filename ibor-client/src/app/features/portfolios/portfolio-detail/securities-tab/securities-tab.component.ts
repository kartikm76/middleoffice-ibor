import { ChangeDetectionStrategy, Component } from '@angular/core';
import { CommonModule } from '@angular/common';

@Component({
  selector: 'app-securities-tab',
  standalone: true,
  imports: [CommonModule],
  templateUrl: './securities-tab.component.html',
  styleUrls: ['./securities-tab.component.scss'],
  changeDetection: ChangeDetectionStrategy.OnPush
})
export class SecuritiesTabComponent {

}
