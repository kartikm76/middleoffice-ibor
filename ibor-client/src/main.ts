// src/main.ts
import { bootstrapApplication } from '@angular/platform-browser';
import { importProvidersFrom } from '@angular/core';
import { AppComponent } from './app/app.component';
import { HttpClientModule } from '@angular/common/http';

bootstrapApplication(AppComponent, {
  providers: [
    importProvidersFrom(HttpClientModule),
    // If you later add routing or animations, you’ll add providers here.
    // provideRouter(routes),
    // provideAnimations(),
  ],
}).catch(err => console.error(err));
