import { ComponentFixture, TestBed } from '@angular/core/testing';

import { AttributionTabComponent } from './attribution-tab.component';

describe('AttributionTabComponent', () => {
  let component: AttributionTabComponent;
  let fixture: ComponentFixture<AttributionTabComponent>;

  beforeEach(() => {
    TestBed.configureTestingModule({
      imports: [AttributionTabComponent]
    });
    fixture = TestBed.createComponent(AttributionTabComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });
});
