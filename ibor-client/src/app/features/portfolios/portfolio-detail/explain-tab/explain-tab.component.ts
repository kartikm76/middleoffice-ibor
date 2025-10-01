import { ChangeDetectionStrategy, Component } from '@angular/core';
import { CommonModule } from '@angular/common';

@Component({
  selector: 'app-explain-tab',
  standalone: true,
  imports: [CommonModule],
  templateUrl: './explain-tab.component.html',
  styleUrls: ['./explain-tab.component.scss'],
  changeDetection: ChangeDetectionStrategy.OnPush
})
export class ExplainTabComponent {

}
