import { ComponentFixture, TestBed } from '@angular/core/testing';

import { PortfolioGridComponent } from './portfolio-grid.component';

describe('PortfolioGridComponent', () => {
  let component: PortfolioGridComponent;
  let fixture: ComponentFixture<PortfolioGridComponent>;

  beforeEach(() => {
    TestBed.configureTestingModule({
      imports: [PortfolioGridComponent]
    });
    fixture = TestBed.createComponent(PortfolioGridComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });
});
