import { Component, inject, signal, effect, ChangeDetectionStrategy, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
// AG Grid
import { AgGridAngular } from 'ag-grid-angular';
import { ColDef, GridApi, ColumnApi, GridReadyEvent, SelectionChangedEvent } from 'ag-grid-community';
// Material UI bits we still use for the search field container
import { MatInputModule } from '@angular/material/input';
import { MatIconModule } from '@angular/material/icon';
import { MatButtonModule } from '@angular/material/button';
import { FormsModule } from '@angular/forms';
import { MatCardModule } from '@angular/material/card';
import { MatToolbarModule } from '@angular/material/toolbar';
import { MatFormFieldModule } from '@angular/material/form-field';
import { AppStateService } from '../../../core/services/app-state/app-state.service';


type Row = { code: string; name: string; benchmark: string; mv: number; twrr: number };

@Component({
  selector: 'app-portfolio-grid',
  standalone: true,
  imports: [CommonModule, AgGridAngular, MatInputModule, MatIconModule, MatButtonModule, FormsModule, MatCardModule, MatToolbarModule, MatFormFieldModule],
  templateUrl: './portfolio-grid.component.html',
  styleUrls: ['./portfolio-grid.component.scss'],
  changeDetection: ChangeDetectionStrategy.OnPush
})
export class PortfolioGridComponent implements OnInit {
  state = inject(AppStateService);

  private all = signal<Row[]>([
    { code: 'ALPHA', name:'Global Growth',  benchmark:'SPX', mv: 1200000, twrr: 0.23 },
    { code: 'BETA',  name:'Balanced Fund', benchmark:'SPX', mv:  950000, twrr: 0.12 },
  ]);

  // Expose a plain array for AG Grid rowData (ensures immediate render)
  rowData: Row[] = this.all();

  // AG Grid APIs
  private gridApi?: GridApi<Row>;
  private columnApi?: ColumnApi;

  // Column definitions
  columnDefs: ColDef<Row>[] = [
    { field: 'code',       headerName: 'Code',       sortable: true, filter: true, width: 140 },
    { field: 'name',       headerName: 'Name',       sortable: true, filter: true, flex: 1, minWidth: 220 },
    { field: 'mv',         headerName: 'MV',         sortable: true, filter: 'agNumberColumnFilter', valueFormatter: p => (p.value ?? 0).toLocaleString(), width: 150, type: 'rightAligned' },
    { field: 'twrr',       headerName: 'TWRR %',     sortable: true, filter: 'agNumberColumnFilter', valueFormatter: p => (p.value ?? 0).toFixed(2), width: 140, type: 'rightAligned' },
    { field: 'benchmark',  headerName: 'Benchmark',  sortable: true, filter: true, width: 150 },
  ];

  defaultColDef: ColDef<Row> = { resizable: true, sortable: true, filter: true };
  rowSelection: 'single' = 'single';

  // Provide the grid with the raw data; filtering is delegated to AG Grid via quick filter
  get data() { return this.all(); }

  // Search box model; uses AG Grid quick filter
  searchText = '';
  onSearch(text: string) {
    this.searchText = text ?? '';
    if (this.gridApi) this.gridApi.setQuickFilter(this.searchText.trim());
  }

  onGridReady(e: GridReadyEvent<Row>) {
    this.gridApi = e.api;
    this.columnApi = e.columnApi;

    // Apply initial quick filter if any
    if (this.searchText) this.gridApi.setQuickFilter(this.searchText.trim());

    // Sync initial selection with AppState or select first row by default
    const sel = this.state.selectedPortfolio();
    if (sel) {
      this.selectRowByCode(sel);
    } else {
      const first = this.all()[0]?.code;
      if (first) this.state.setPortfolio(first);
      if (first) this.selectRowByCode(first);
    }
  }

  onSelectionChanged(e: SelectionChangedEvent<Row>) {
    const node = e.api.getSelectedNodes()[0];
    const code = node?.data?.code;
    if (code && this.state.selectedPortfolio() !== code) this.state.setPortfolio(code);
  }

  private selectRowByCode(code: string) {
    if (!this.gridApi) return;
    this.gridApi.forEachNode(node => {
      if (node.data?.code === code && !node.isSelected()) node.setSelected(true);
    });
  }

  // Keep grid selection in sync if selectedPortfolio signal changes elsewhere
  init = effect(() => {
    const code = this.state.selectedPortfolio();
    if (code && this.gridApi) this.selectRowByCode(code);
  });

  ngOnInit(): void {
    this.ensureGridStyles();
  }

  private ensureGridStyles() {
    const d = document;
    const base = d.querySelector('base')?.getAttribute('href') || '/';
    const join = (p: string) => (base.endsWith('/') ? base : base + '/') + p.replace(/^\//, '');

    const ensure = (id: string, href: string) => {
      if (d.getElementById(id)) return;
      const link = d.createElement('link');
      link.id = id;
      link.rel = 'stylesheet';
      link.href = href;
      d.head.appendChild(link);
    };

    ensure('ag-grid-base-css', join('assets/vendor/ag-grid/ag-grid.css'));
    ensure('ag-theme-alpine-css', join('assets/vendor/ag-grid/ag-theme-alpine.css'));
  }
}
