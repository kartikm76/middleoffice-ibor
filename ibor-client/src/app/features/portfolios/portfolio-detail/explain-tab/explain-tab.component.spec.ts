import { ComponentFixture, TestBed } from '@angular/core/testing';

import { ExplainTabComponent } from './explain-tab.component';

describe('ExplainTabComponent', () => {
  let component: ExplainTabComponent;
  let fixture: ComponentFixture<ExplainTabComponent>;

  beforeEach(() => {
    TestBed.configureTestingModule({
      imports: [ExplainTabComponent]
    });
    fixture = TestBed.createComponent(ExplainTabComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });
});
