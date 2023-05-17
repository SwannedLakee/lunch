import PropTypes from "prop-types";
import React from "react";
import withStyles from "isomorphic-style-loader/withStyles";
import s from "./Tag.scss";

const Tag = ({ name, showDelete, onDeleteClicked, exclude }) => {
  let deleteButton = null;
  if (showDelete) {
    deleteButton = (
      <button type="button" className={s.button} onClick={onDeleteClicked}>
        &times;
      </button>
    );
  }

  return (
    <div className={`${s.root} ${exclude ? s.exclude : ""}`}>
      {name}
      {deleteButton}
    </div>
  );
};

Tag.propTypes = {
  name: PropTypes.string.isRequired,
  showDelete: PropTypes.bool.isRequired,
  onDeleteClicked: PropTypes.func.isRequired,
  exclude: PropTypes.bool,
};

Tag.defaultProps = {
  exclude: false,
};

export const undecorated = Tag;
export default withStyles(s)(Tag);
