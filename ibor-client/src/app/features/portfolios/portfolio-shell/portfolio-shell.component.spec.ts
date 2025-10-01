import { ComponentFixture, TestBed } from '@angular/core/testing';

import { PortfolioShellComponent } from './portfolio-shell.component';

describe('PortfolioShellComponent', () => {
  let component: PortfolioShellComponent;
  let fixture: ComponentFixture<PortfolioShellComponent>;

  beforeEach(() => {
    TestBed.configureTestingModule({
      imports: [PortfolioShellComponent]
    });
    fixture = TestBed.createComponent(PortfolioShellComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });
});
