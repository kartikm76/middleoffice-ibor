export type PortfolioRow = {
  code: string;
  name: string;
  mv: number;
  twrr: number;
  benchmark: string;
};

export type ColumnCfg<T> = {
  id: keyof T & string;
  header: string;
  cell?: (row: T) => string | number;
  align?: 'start' | 'center' | 'end';
};

export const PORTFOLIO_COLUMNS: ColumnCfg<PortfolioRow>[] = [
  { id: 'code',       header: 'Code' },
  { id: 'name',       header: 'Name' },
  { id: 'mv',         header: 'MV',        cell: r => r.mv.toLocaleString() , align: 'end' },
  { id: 'twrr',       header: 'TWRR %',    cell: r => r.twrr.toFixed(2),      align: 'end' },
  { id: 'benchmark',  header: 'Benchmark' }
];
