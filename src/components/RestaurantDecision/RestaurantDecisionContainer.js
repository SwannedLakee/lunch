import { connect } from 'react-redux';
import { getDecision } from '../../selectors/decisions';
import { getRestaurantById } from '../../selectors/restaurants';
import { decide, removeDecision } from '../../actions/decisions';
import RestaurantDecision from './RestaurantDecision';

const mapStateToProps = (state, ownProps) => {
  const decision = getDecision(state);
  return {
    id: ownProps.id,
    loggedIn: state.user.id !== undefined,
    decided: decision !== undefined && decision.restaurant_id === ownProps.id,
    votes: getRestaurantById(state, ownProps.id).votes
  };
};

const mapDispatchToProps = dispatch => ({
  dispatch
});

const mergeProps = (stateProps, dispatchProps, ownProps) => ({
  ...stateProps,
  ...dispatchProps,
  handleClick() {
    if (stateProps.loggedIn) {
      if (stateProps.decided) {
        dispatchProps.dispatch(removeDecision());
      } else {
        dispatchProps.dispatch(decide(ownProps.id));
      }
    }
  },
});

export default connect(
  mapStateToProps,
  mapDispatchToProps,
  mergeProps
)(RestaurantDecision);
