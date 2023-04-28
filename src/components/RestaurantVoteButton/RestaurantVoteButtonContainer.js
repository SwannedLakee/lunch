import { connect } from 'react-redux';
import { makeGetRestaurantVotesForUser } from '../../selectors';
import { removeVote, addVote } from '../../actions/restaurants';
import RestaurantVoteButton from './RestaurantVoteButton';

const mapStateToProps = () => {
  const getRestaurantVotesForUser = makeGetRestaurantVotesForUser();
  return (state, ownProps) => {
    const props = { restaurantId: ownProps.id, userId: state.user.id };
    return {
      userVotes: getRestaurantVotesForUser(state, props)
    };
  };
};

const mapDispatchToProps = null;

const mergeProps = (stateProps, dispatchProps, ownProps) => ({
  ...stateProps,
  ...dispatchProps,
  handleClick: () => {
    if (stateProps.userVotes.length > 0) {
      stateProps.userVotes.forEach(vote => {
        dispatchProps.dispatch(removeVote(ownProps.id, vote));
      });
    } else {
      dispatchProps.dispatch(addVote(ownProps.id));
    }
  }
});

export default connect(
  mapStateToProps,
  mapDispatchToProps,
  mergeProps
)(RestaurantVoteButton);
