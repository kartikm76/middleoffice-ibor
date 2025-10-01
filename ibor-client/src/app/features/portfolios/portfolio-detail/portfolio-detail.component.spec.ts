import { ComponentFixture, TestBed } from '@angular/core/testing';

import { PortfolioDetailComponent } from './portfolio-detail.component';

describe('PortfolioDetailComponent', () => {
  let component: PortfolioDetailComponent;
  let fixture: ComponentFixture<PortfolioDetailComponent>;

  beforeEach(() => {
    TestBed.configureTestingModule({
      imports: [PortfolioDetailComponent]
    });
    fixture = TestBed.createComponent(PortfolioDetailComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });
});
