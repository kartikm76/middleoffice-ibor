import { NgModule } from '@angular/core';
import { BrowserModule } from '@angular/platform-browser';

import { AppRoutingModule } from './app-routing.module';
import { AppComponent } from './app.component';
import {PortfolioGridComponent} from "./features/portfolios/portfolio-grid/portfolio-grid.component";

@NgModule({
  declarations: [
    AppComponent
  ],
    imports: [
        BrowserModule,
        AppRoutingModule,
        PortfolioGridComponent
    ],
  providers: [],
  bootstrap: [AppComponent]
})
export class AppModule { }
