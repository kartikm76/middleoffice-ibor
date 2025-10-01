import { ChangeDetectionStrategy, Component } from '@angular/core';
import { CommonModule } from '@angular/common';

@Component({
  selector: 'app-notes-tab',
  standalone: true,
  imports: [CommonModule],
  templateUrl: './notes-tab.component.html',
  styleUrls: ['./notes-tab.component.scss'],
  changeDetection: ChangeDetectionStrategy.OnPush
})
export class NotesTabComponent {

}
