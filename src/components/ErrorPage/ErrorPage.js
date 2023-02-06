/**
 * React Starter Kit (https://www.reactstarterkit.com/)
 *
 * Copyright © 2014-2016 Kriasoft, LLC. All rights reserved.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE.txt file in the root directory of this source tree.
 */

import PropTypes from 'prop-types';
import React from 'react';
import withStyles from 'isomorphic-style-loader/withStyles';
import s from './ErrorPage.scss';

export function ErrorPage({ error }) {
  let title = 'Error';
  let content = 'Sorry, a critical error occurred on this page.';
  let errorMessage = null;

  if (error.status === 404) {
    title = 'Page not found';
    content = 'Sorry, the page you were trying to view does not exist.';
  } else if (process.env.NODE_ENV !== 'production') {
    errorMessage = <pre>{error.stack}</pre>;
  }

  return (
    <div>
      <h1>{title}</h1>
      <p>{content}</p>
      {errorMessage}
    </div>
  );
}

ErrorPage.propTypes = { error: PropTypes.object.isRequired };

export { ErrorPage as ErrorPageWithoutStyle };
export default withStyles(s)(ErrorPage);
