import { connect } from "react-redux";
import { getTagById } from "../../selectors/tags";
import Tag from "./Tag";

const mapStateToProps = () => {
  let name;
  return (state, ownProps) => {
    if (ownProps.name === undefined) {
      const tag = getTagById(state, ownProps.id);
      if (tag !== undefined) {
        name = tag.name;
      }
    } else {
      name = ownProps.name;
    }
    return {
      name,
      exclude: ownProps.exclude,
    };
  };
};

export default connect(mapStateToProps)(Tag);
