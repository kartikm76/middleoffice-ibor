import { ChangeDetectionStrategy, Component } from '@angular/core';
import { CommonModule } from '@angular/common';

@Component({
  selector: 'app-transactions-tab',
  standalone: true,
  imports: [CommonModule],
  templateUrl: './transactions-tab.component.html',
  styleUrls: ['./transactions-tab.component.scss'],
  changeDetection: ChangeDetectionStrategy.OnPush
})
export class TransactionsTabComponent {

}
