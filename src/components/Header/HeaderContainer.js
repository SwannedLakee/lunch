import { connect } from "react-redux";
import { isLoggedIn } from "../../selectors/user";
import Header from "./Header";

const mapStateToProps = (state, ownProps) => ({
  flashes: state.flashes,
  loggedIn: isLoggedIn(state),
  path: ownProps.path,
});

export default connect(mapStateToProps)(Header);
