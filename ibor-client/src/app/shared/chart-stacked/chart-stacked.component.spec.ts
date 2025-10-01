import { ComponentFixture, TestBed } from '@angular/core/testing';

import { ChartStackedComponent } from './chart-stacked.component';

describe('ChartStackedComponent', () => {
  let component: ChartStackedComponent;
  let fixture: ComponentFixture<ChartStackedComponent>;

  beforeEach(() => {
    TestBed.configureTestingModule({
      imports: [ChartStackedComponent]
    });
    fixture = TestBed.createComponent(ChartStackedComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });
});
