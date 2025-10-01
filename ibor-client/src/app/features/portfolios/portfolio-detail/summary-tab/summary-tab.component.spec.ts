import { ComponentFixture, TestBed } from '@angular/core/testing';

import { SummaryTabComponent } from './summary-tab.component';

describe('SummaryTabComponent', () => {
  let component: SummaryTabComponent;
  let fixture: ComponentFixture<SummaryTabComponent>;

  beforeEach(() => {
    TestBed.configureTestingModule({
      imports: [SummaryTabComponent]
    });
    fixture = TestBed.createComponent(SummaryTabComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });
});
