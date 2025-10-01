import { ComponentFixture, TestBed } from '@angular/core/testing';

import { TransactionsTabComponent } from './transactions-tab.component';

describe('TransactionsTabComponent', () => {
  let component: TransactionsTabComponent;
  let fixture: ComponentFixture<TransactionsTabComponent>;

  beforeEach(() => {
    TestBed.configureTestingModule({
      imports: [TransactionsTabComponent]
    });
    fixture = TestBed.createComponent(TransactionsTabComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });
});
