import { ComponentFixture, TestBed } from '@angular/core/testing';

import { ChartLineComponent } from './chart-line.component';

describe('ChartLineComponent', () => {
  let component: ChartLineComponent;
  let fixture: ComponentFixture<ChartLineComponent>;

  beforeEach(() => {
    TestBed.configureTestingModule({
      imports: [ChartLineComponent]
    });
    fixture = TestBed.createComponent(ChartLineComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });
});
