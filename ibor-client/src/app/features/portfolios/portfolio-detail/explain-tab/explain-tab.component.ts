// Angular component for the Explain tab, allowing users to ask RAG-based questions about notes
import { Component, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { RagApiService } from '../../../../core/services/api/rag-api/rag-api.service';
import { AppStateService } from '../../../../core/services/app-state/app-state.service';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatInputModule } from '@angular/material/input';
import { MatButtonModule } from '@angular/material/button';
import { MatProgressBarModule } from '@angular/material/progress-bar';
import { FormsModule } from '@angular/forms';

@Component({
  selector: 'app-explain-tab',
  standalone: true,
  imports: [CommonModule, FormsModule, MatFormFieldModule, MatInputModule, MatButtonModule, MatProgressBarModule],
  templateUrl: './explain-tab.component.html'
})
export class ExplainTabComponent {
  // Inject RAG API and application state services
  private api = inject(RagApiService);
  private state = inject(AppStateService);

  // Signals for question, ticker, loading, error, and answer
  q = signal('What changed in IBM notes last week?');
  ticker = signal('IBM'); // Optional instrument ticker
  loading = signal(false);
  error = signal<string | null>(null);
  answer = signal<string | null>(null);

  // ngModel properties for form fields
  public qValue = this.q();
  public tickerValue = this.ticker();

  // Ask the RAG API a question and handle the response
  ask() {
    // Sync ngModel values to signals
    this.q.set(this.qValue);
    this.ticker.set(this.tickerValue);
    this.loading.set(true);
    this.error.set(null);
    this.answer.set(null);
    const pf = this.state.selectedPortfolio();
    (this.api.askHybrid({
      question: this.q(),
      instrumentTicker: this.ticker() || null,
      portfolioCodes: pf ? [pf] : null,
      topK: 5
    }) as any).subscribe({
      next: (res: any) => { this.answer.set(res.answer); this.loading.set(false); },
      error: (e: any) => { this.error.set(e?.message ?? 'Failed'); this.loading.set(false); }
    });
  }
}
