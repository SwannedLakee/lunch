/* eslint-env mocha */
import fetchMock from "fetch-mock";

afterEach(() => {
  fetchMock.restore();
});
