import { ComponentFixture, TestBed } from '@angular/core/testing';

import { SecuritiesTabComponent } from './securities-tab.component';

describe('SecuritiesTabComponent', () => {
  let component: SecuritiesTabComponent;
  let fixture: ComponentFixture<SecuritiesTabComponent>;

  beforeEach(() => {
    TestBed.configureTestingModule({
      imports: [SecuritiesTabComponent]
    });
    fixture = TestBed.createComponent(SecuritiesTabComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });
});
