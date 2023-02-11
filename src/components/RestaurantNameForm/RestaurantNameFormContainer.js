import { connect } from 'react-redux';
import { getListUiItemForId } from '../../selectors/listUi';
import { changeRestaurantName } from '../../actions/restaurants';
import { hideEditNameForm, setEditNameFormValue } from '../../actions/listUi';
import RestaurantNameForm from './RestaurantNameForm';

const mapStateToProps = (state, ownProps) => {
  const listUiItem = getListUiItemForId(state, ownProps.id);
  return {
    editNameFormValue: listUiItem.editNameFormValue || ''
  };
};

const mapDispatchToProps = (dispatch, ownProps) => ({
  hideEditNameForm: () => {
    dispatch(hideEditNameForm(ownProps.id));
  },
  setEditNameFormValue: event => {
    dispatch(setEditNameFormValue(ownProps.id, event.target.value));
  },
  dispatch
});

const mergeProps = (stateProps, dispatchProps, ownProps) => ({
  ...stateProps,
  ...dispatchProps,
  changeRestaurantName: event => {
    event.preventDefault();
    dispatchProps.dispatch(
      changeRestaurantName(ownProps.id, stateProps.editNameFormValue)
    );
  }
});

export default connect(
  mapStateToProps,
  mapDispatchToProps,
  mergeProps
)(RestaurantNameForm);
