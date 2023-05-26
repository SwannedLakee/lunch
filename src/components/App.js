/**
 * React Starter Kit (https://www.reactstarterkit.com/)
 *
 * Copyright © 2014-present Kriasoft, LLC. All rights reserved.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE.txt file in the root directory of this source tree.
 */

import StyleContext from "isomorphic-style-loader/StyleContext";
import PropTypes from "prop-types";
import React, { Children } from "react";
import { Provider as ReduxProvider } from "react-redux";
import { Loader } from "@googlemaps/js-api-loader";
import IntlProviderContainer from "./IntlProvider/IntlProviderContainer";
import GoogleMapsLoaderContext from "./GoogleMapsLoaderContext/GoogleMapsLoaderContext";

const ContextType = {
  // Enables critical path CSS rendering
  // https://github.com/kriasoft/isomorphic-style-loader
  insertCss: PropTypes.func.isRequired,
  googleApiKey: PropTypes.string.isRequired,
  pathname: PropTypes.string.isRequired,
  query: PropTypes.object,
  store: PropTypes.object.isRequired,
  // Integrate Redux
  // http://redux.js.org/docs/basics/UsageWithReact.html
  ...ReduxProvider.childContextTypes,
};

/**
 * The top-level React component setting context (global) variables
 * that can be accessed from all the child components.
 *
 * https://facebook.github.io/react/docs/context.html
 *
 * Usage example:
 *
 *   const context = {
 *     history: createBrowserHistory(),
 *     store: createStore(),
 *   };
 *
 *   ReactDOM.render(
 *     <App context={context}>
 *       <Layout>
 *         <LandingPage />
 *       </Layout>
 *     </App>,
 *     container,
 *   );
 */
class App extends React.PureComponent {
  static propTypes = {
    context: PropTypes.shape(ContextType).isRequired,
    children: PropTypes.element.isRequired,
  };

  static childContextTypes = ContextType;

  constructor(props) {
    super(props);

    this.loaderContextValue = {
      loader: new Loader({
        apiKey: this.props.context.googleApiKey,
        version: "weekly",
        libraries: ["places", "geocoding"],
      }),
    };

    this.styleContextValue = { insertCss: props.context.insertCss };
  }

  getChildContext() {
    return this.props.context;
  }

  render() {
    // NOTE: If you need to add or modify header, footer etc. of the app,
    // please do that inside the Layout component.
    return (
      <StyleContext.Provider value={this.styleContextValue}>
        <ReduxProvider store={this.props.context.store}>
          <IntlProviderContainer>
            <GoogleMapsLoaderContext.Provider value={this.loaderContextValue}>
              {Children.only(this.props.children)}
            </GoogleMapsLoaderContext.Provider>
          </IntlProviderContainer>
        </ReduxProvider>
      </StyleContext.Provider>
    );
  }
}

export default App;
