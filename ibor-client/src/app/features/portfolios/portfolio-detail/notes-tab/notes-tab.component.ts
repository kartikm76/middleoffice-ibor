// Angular component for the Notes tab, allowing users to submit notes
import { Component, inject, signal, ChangeDetectionStrategy } from '@angular/core';
import { CommonModule } from '@angular/common';
import { NotesApiService } from '../../../../core/services/api/notes-api/notes-api.service';
import { IngestNoteRequest } from '../../../../core/services/api/notes-api/notes-api.models';
import { AppStateService } from '../../../../core/services/app-state/app-state.service';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatInputModule } from '@angular/material/input';
import { MatButtonModule } from '@angular/material/button';
import { MatProgressBarModule } from '@angular/material/progress-bar';
import { FormsModule } from '@angular/forms';

@Component({
  selector: 'app-notes-tab',
  standalone: true,
  imports: [CommonModule, FormsModule, MatFormFieldModule, MatInputModule, MatButtonModule, MatProgressBarModule],
  templateUrl: './notes-tab.component.html',
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class NotesTabComponent {
  // Inject Notes API and application state services
  private api = inject(NotesApiService);
  private state = inject(AppStateService);

  // Signals for form fields (default values for demonstration)
  title = signal('Weekly update');
  author = signal('PM Desk');
  text = signal('Trimmed IBM by 20bps; strength into earnings.');
  tickers = signal('IBM');        // Comma-separated tickers for UI simplicity
  portfolios = signal('ALPHA');   // Comma-separated portfolio codes

  // Signals for result, error, and loading state
  result = signal<unknown | null>(null);
  error  = signal<string | null>(null);
  loading = signal(false);

  // ngModel properties for form fields
  titleValue = this.title();
  authorValue = this.author();
  textValue = this.text();
  tickersValue = this.tickers();
  portfoliosValue = this.portfolios();

  // Submit the note to the API
  submit() {
    // Sync ngModel values to signals
    this.title.set(this.titleValue);
    this.author.set(this.authorValue);
    this.text.set(this.textValue);
    this.tickers.set(this.tickersValue);
    this.portfolios.set(this.portfoliosValue);
    this.loading.set(true);
    this.error.set(null);
    // Build the request object from form signals
    const req: IngestNoteRequest = {
      title: this.title(),
      author: this.author(),
      text: this.text(),
      instrumentTickers: this.tickers().split(',').map(s => s.trim()).filter(Boolean),
      portfolioCodes: this.portfolios().split(',').map(s => s.trim()).filter(Boolean),
    };
    // Call the API and handle result, error, and loading state
    (this.api.ingest(req) as any).subscribe({
      next: (res: any) => { this.result.set(res); this.loading.set(false); },
      error: (e: any) => { this.error.set(e?.message ?? 'Failed'); this.loading.set(false); }
    });
  }
}
