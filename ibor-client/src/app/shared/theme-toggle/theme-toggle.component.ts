import { Component } from '@angular/core';

@Component({
  selector: 'app-theme-toggle',
  standalone: true,
  templateUrl: './theme-toggle.component.html',
  styleUrls: ['./theme-toggle.component.scss']
})
export class ThemeToggleComponent {
  isDark = true;

  constructor() {
    const saved = localStorage.getItem('ibor:theme');
    if (saved) {
      this.isDark = saved === 'dark';
      this.apply();
    } else {
      this.apply();
    }
  }

  toggle() {
    this.isDark = !this.isDark;
    localStorage.setItem('ibor:theme', this.isDark ? 'dark' : 'light');
    this.apply();
  }

  apply() {
    if (typeof document === 'undefined') return;
    document.body.classList.toggle('dark-theme', this.isDark);
    document.body.classList.toggle('light-theme', !this.isDark);
  }
}

