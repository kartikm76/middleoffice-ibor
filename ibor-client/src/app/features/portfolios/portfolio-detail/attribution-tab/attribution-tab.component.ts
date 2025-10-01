import { ChangeDetectionStrategy, Component } from '@angular/core';
import { CommonModule } from '@angular/common';

@Component({
  selector: 'app-attribution-tab',
  standalone: true,
  imports: [CommonModule],
  templateUrl: './attribution-tab.component.html',
  styleUrls: ['./attribution-tab.component.scss'],
  changeDetection: ChangeDetectionStrategy.OnPush
})
export class AttributionTabComponent {

}
