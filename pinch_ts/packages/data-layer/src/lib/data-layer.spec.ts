import { dataLayer } from './data-layer';

describe('dataLayer', () => {
  it('should work', () => {
    expect(dataLayer()).toEqual('data-layer');
  });
});
